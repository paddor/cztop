# frozen_string_literal: true

require_relative 'spec_helper'

# NOTE: Async 2 requires Ruby 3.1
# NOTE: IO::TimeoutError was introduced in 3.2, so lets focus on 3.2+
describe 'Async::IO::CZTopSocket', if: (RUBY_VERSION >= '3.2') do
  require_relative '../../lib/cztop/async'

  i = 0
  let(:endpoint)   { "inproc://async_endpoint_socket_spec_reqrep_#{i += 1}" }
  let(:req_socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:rep_socket) { CZTop::Socket::REP.new(endpoint) }
  let(:req_io)     { Async::IO.try_convert req_socket }
  let(:rep_io)     { Async::IO.try_convert rep_socket }


  it 'can be converted to Async::IO' do
    assert_kind_of Async::IO::CZTopSocket, req_io
    assert_kind_of Async::IO::CZTopSocket, rep_io
  end

  it 'can send and receive' do
    Async do |task|
      rep_socket
      req_socket

      sleep 0.1
      req_io = Async::IO.try_convert req_socket
      rep_io = Async::IO.try_convert rep_socket

      task.async do |task|
        msg = rep_io.receive
        word, = msg.to_a
        rep_io << word.upcase
      end

      task.async do |task|
        req_io << 'hello'
        response, = req_io.receive.to_a
        # p response: response
        assert_equal 'HELLO', response
      end
    end
  end


  describe '#read_timeout' do
    describe 'with no rcvtimeout set' do
      before do
        assert_equal -1, req_socket.options.rcvtimeo
      end

      it 'returns nil' do
        assert_nil req_io.read_timeout
      end
    end

    # NOTE: 0 would mean non-block (EAGAIN), but that's obsolete with Async
    describe 'with no rcvtimeout=0' do
      before do
        req_socket.options.rcvtimeo = 0
      end

      it 'returns nil' do
        assert_nil req_io.read_timeout
      end
    end

    describe 'with rcvtimeout set' do
      before do
        req_socket.options.rcvtimeo = 10 # ms
      end

      it 'returns timeout in seconds' do
        assert_equal 0.01, req_io.read_timeout
      end
    end
  end


  describe '#write_timeout' do
    describe 'with no sndtimeout set' do
      before do
        assert_equal -1, req_socket.options.sndtimeo
      end

      it 'returns nil' do
        assert_nil req_io.write_timeout
      end
    end

    # NOTE: 0 would mean non-block (EAGAIN), but that's obsolete with Async
    describe 'with sndtimeout=0' do
      before do
        req_socket.options.sndtimeo = 0
      end

      it 'returns nil' do
        assert_nil req_io.write_timeout
      end
    end

    describe 'with sndtimeout set' do
      before do
        req_socket.options.sndtimeo = 10
      end

      it 'returns timeout in seconds' do
        assert_equal 0.01, req_io.write_timeout
      end
    end
  end


  context 'with rcvtimeo' do
    before do
      req_socket.options.rcvtimeo = 30
      assert_equal 30, req_socket.options.rcvtimeo
    end

    it 'will raise TimeoutError' do
      Async do
        assert_raises ::IO::TimeoutError do
          req_io.receive
        end
      end
    end
  end


  context 'with sndtimeo' do
    before do
      rep_socket.options.sndtimeo = 30
      assert_equal 30, rep_socket.options.sndtimeo
    end

    it 'will raise TimeoutError' do
      Async do
        assert_raises ::IO::TimeoutError do
          rep_io << ['foo']
        end
      end
    end
  end


  describe 'thread-safe sockets', if: has_czmq_drafts? do
    let(:endpoint)      { "inproc://async_endpoint_socket_spec_serverclient_#{i += 1}" }
    let(:server_socket) { CZTop::Socket::SERVER.new(endpoint) }
    let(:client_socket) { CZTop::Socket::CLIENT.new(endpoint) }

    it 'does not convert thread-safe sockets' do
      assert_raises ArgumentError do
        Async::IO.try_convert server_socket
      end

      assert_raises ArgumentError do
        Async::IO.try_convert client_socket
      end
    end
  end
end
