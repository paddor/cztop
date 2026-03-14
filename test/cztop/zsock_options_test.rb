# frozen_string_literal: true

require_relative 'test_helper'

describe CZTop::ZsockOptions do
  include ZMQHelper

  i = 0
  let(:endpoint) { "inproc://zsock_options_#{i += 1}" }
  let(:socket)   { CZTop::Socket::REQ.new(endpoint) }


  describe 'event-based methods' do
    describe '#readable?' do
      describe 'with read event set' do
        it 'returns true' do
          socket.stub(:events, CZTop::ZsockOptions::POLLIN) do
            assert_operator socket, :readable?
          end
        end
      end


      describe 'with read event unset' do
        it 'returns false' do
          socket.stub(:events, 0) do
            refute_operator socket, :readable?
          end
        end
      end
    end


    describe '#writable?' do
      describe 'with write event set' do
        it 'returns true' do
          socket.stub(:events, CZTop::ZsockOptions::POLLOUT) do
            assert_operator socket, :writable?
          end
        end
      end


      describe 'with write event unset' do
        it 'returns false' do
          socket.stub(:events, 0) do
            refute_operator socket, :writable?
          end
        end
      end
    end
  end


  describe '#fd' do
    it 'returns socket FD' do
      fd_type = FFI::Platform.unix? ? Integer : FFI::Pointer
      assert_kind_of(fd_type, socket.fd)
    end
  end


  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
      assert_equal socket.fd, socket.to_io.fileno
    end

    it 'will not autoclose' do
      refute_operator socket.to_io, :autoclose?
    end
  end


  describe '#sndhwm' do
    describe 'when getting current value' do
      it 'returns value' do
        assert_kind_of Integer, socket.sndhwm
      end
    end


    describe 'when setting new value' do
      let(:new_value) { 99 }
      before { socket.sndhwm = new_value }

      it 'sets new value' do
        assert_equal new_value, socket.sndhwm
      end
    end
  end


  describe '#rcvhwm' do
    describe 'when getting current value' do
      it 'returns value' do
        assert_kind_of Integer, socket.rcvhwm
      end
    end


    describe 'when setting new value' do
      let(:new_value) { 99 }
      before { socket.rcvhwm = new_value }

      it 'sets new value' do
        assert_equal new_value, socket.rcvhwm
      end
    end
  end


  describe '#send_timeout' do
    it 'returns nil by default (no timeout)' do
      assert_nil socket.send_timeout
    end

    it 'sets and gets send timeout' do
      socket.send_timeout = 0.007
      assert_equal 0.007, socket.send_timeout

      socket.send_timeout = 0
      assert_equal 0, socket.send_timeout
    end

    it 'accepts nil to reset to no timeout' do
      socket.send_timeout = 0.007
      socket.send_timeout = nil
      assert_nil socket.send_timeout
    end
  end


  describe '#recv_timeout' do
    it 'returns nil by default (no timeout)' do
      assert_nil socket.recv_timeout
    end

    it 'sets and gets receive timeout' do
      socket.recv_timeout = 0.007
      assert_equal 0.007, socket.recv_timeout
    end

    it 'accepts nil to reset to no timeout' do
      socket.recv_timeout = 0.007
      socket.recv_timeout = nil
      assert_nil socket.recv_timeout
    end
  end


  describe '#read_timeout / #write_timeout aliases' do
    it '#read_timeout is an alias for #recv_timeout' do
      socket.recv_timeout = 0.5
      assert_equal 0.5, socket.read_timeout
    end

    it '#read_timeout= is an alias for #recv_timeout=' do
      socket.read_timeout = 0.5
      assert_equal 0.5, socket.recv_timeout
    end

    it '#write_timeout is an alias for #send_timeout' do
      socket.send_timeout = 0.5
      assert_equal 0.5, socket.write_timeout
    end

    it '#write_timeout= is an alias for #send_timeout=' do
      socket.write_timeout = 0.5
      assert_equal 0.5, socket.send_timeout
    end
  end


  describe '#router_mandatory=' do
    let(:router) { CZTop::Socket::ROUTER.new(endpoint) }

    it 'can set the flag' do
      called_with = nil
      CZMQ::FFI::Zsock.stub(:set_router_mandatory, ->(*args) { called_with = args }) do
        router.router_mandatory = true
      end
      assert_equal [router, 1], called_with
    end

    it 'can unset the flag' do
      called_with = nil
      CZMQ::FFI::Zsock.stub(:set_router_mandatory, ->(*args) { called_with = args }) do
        router.router_mandatory = false
      end
      assert_equal [router, 0], called_with
    end
  end


  describe '#router_mandatory?' do
    let(:router) { CZTop::Socket::ROUTER.new(endpoint) }

    it 'gets the flag' do
      refute_operator router, :router_mandatory?
      router.router_mandatory = true
      assert_operator router, :router_mandatory?
      router.router_mandatory = false
      refute_operator router, :router_mandatory?
    end
  end


  describe '#identity' do
    describe 'with no identity set' do
      it 'returns empty string' do
        assert_equal '', socket.identity
      end
    end


    describe 'with identity set' do
      let(:identity) { 'foobar' }
      before { socket.identity = identity }

      it 'returns identity' do
        assert_equal identity, socket.identity
      end
    end
  end


  describe '#identity=' do
    describe 'with zero-length identity' do
      it 'raises' do
        assert_raises(ArgumentError) { socket.identity = '' }
      end
    end


    describe 'with invalid identity' do
      # NOTE: leading null byte is reserved for ZMQ
      it 'raises' do
        assert_raises(ArgumentError) { socket.identity = "\x00foobar" }
      end
    end


    describe 'with too long identity' do
      # NOTE: identities are 255 bytes maximum
      it 'raises' do
        assert_raises(ArgumentError) { socket.identity = 'x' * 256 }
      end
    end
  end


  describe '#tos' do
    describe 'with no TOS' do
      it 'returns zero' do
        assert_equal 0, socket.tos
      end
    end


    describe 'with TOS set' do
      let(:tos) { 5 }
      before { socket.tos = tos }

      it 'returns TOS' do
        assert_equal tos, socket.tos
      end
    end


    describe 'with invalid TOS' do
      it 'raises' do
        assert_raises(ArgumentError) { socket.tos = -5 }
      end
    end


    describe 'when resetting to zero' do
      before { socket.tos = 10 }

      it "doesn't raise" do
        socket.tos = 0
      end
    end
  end


  describe '#linger' do
    it 'returns 0 by default' do
      assert_equal 0, socket.linger
    end

    it 'sets and gets value' do
      socket.linger = 0.5
      assert_equal 0.5, socket.linger
    end

    it 'accepts nil for indefinite linger' do
      socket.linger = nil
      assert_nil socket.linger
    end
  end


  describe '#heartbeat_ivl' do
    it 'returns default' do
      assert_equal 0, socket.heartbeat_ivl
    end

    it 'sets and gets value' do
      socket.heartbeat_ivl = 0.5
      assert_equal 0.5, socket.heartbeat_ivl
    end

    it 'raises on negative value' do
      assert_raises(ArgumentError) { socket.heartbeat_ivl = -1 }
    end
  end


  describe '#heartbeat_ttl' do
    it 'returns default' do
      assert_equal 0, socket.heartbeat_ttl
    end

    it 'sets and gets value' do
      socket.heartbeat_ttl = 1
      assert_equal 1.0, socket.heartbeat_ttl
    end

    it 'raises on out-of-range value' do
      assert_raises(ArgumentError) { socket.heartbeat_ttl = 100 }
    end
  end


  describe '#heartbeat_timeout' do
    it 'returns nil by default' do
      assert_nil socket.heartbeat_timeout
    end

    it 'sets and gets value' do
      socket.heartbeat_timeout = 5
      assert_equal 5.0, socket.heartbeat_timeout
    end

    it 'accepts nil to reset to default' do
      socket.heartbeat_timeout = 5
      socket.heartbeat_timeout = nil
      assert_equal 0.0, socket.heartbeat_timeout
    end

    it 'raises on negative value' do
      assert_raises(ArgumentError) { socket.heartbeat_timeout = -1 }
    end
  end


  describe '#ipv6=' do
    it 'can enable IPv6' do
      called_with = nil
      CZMQ::FFI::Zsock.stub(:set_ipv6, ->(*args) { called_with = args }) do
        socket.ipv6 = true
      end
      assert_equal [socket, 1], called_with
    end

    it 'can disable IPv6' do
      called_with = nil
      CZMQ::FFI::Zsock.stub(:set_ipv6, ->(*args) { called_with = args }) do
        socket.ipv6 = false
      end
      assert_equal [socket, 0], called_with
    end
  end


  describe '#ipv6?' do
    describe 'with default setting' do
      it 'returns false' do
        refute_operator socket, :ipv6?
      end
    end


    describe 'with ipv6 enabled' do
      before { socket.ipv6 = true }

      it 'returns true' do
        assert_operator socket, :ipv6?
      end
    end


    describe 'with ipv6 disabled' do
      before { socket.ipv6 = false }

      it 'returns false' do
        refute_operator socket, :ipv6?
      end
    end
  end


  describe '#reconnect_ivl' do
    it 'returns 0.1 by default' do
      assert_equal 0.1, socket.reconnect_ivl
    end

    it 'sets and gets value' do
      socket.reconnect_ivl = 0.5
      assert_equal 0.5, socket.reconnect_ivl
    end

    it 'accepts nil to disable reconnection' do
      socket.reconnect_ivl = nil
      assert_nil socket.reconnect_ivl
    end
  end


  describe '#events' do
    let(:writer) { CZTop::Socket::PUSH.new(endpoint) }
    let(:reader) { CZTop::Socket::PULL.new(endpoint) }


    describe 'with readable socket' do
      before { writer << 'foo' }

      it 'is readable' do
        assert_operator reader, :readable?
      end
    end


    describe 'with non-readable socket' do
      it 'is not readable' do
        refute_operator reader, :readable?
      end
    end


    describe 'with writable socket' do
      it 'is writable' do
        assert_operator writer, :writable?
      end
    end


    describe 'with non-writable socket' do
      let(:full_writer) do
        sock = CZTop::Socket::PUSH.new
        sock.sndhwm = 1
        sock.connect(endpoint)
        sock << 'is now full'
        sock
      end

      it 'is not writable' do
        refute_operator full_writer, :writable?
      end
    end
  end
end
