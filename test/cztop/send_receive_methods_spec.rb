# frozen_string_literal: true

require_relative 'spec_helper'

describe CZTop::SendReceiveMethods do
  let(:zocket) do
    o = Object.new
    o.extend CZTop::SendReceiveMethods
    o
  end


  describe '#<<' do
    describe 'when sending message' do
      let(:content) { 'foobar' }

      it 'sends content' do
        sent_to = nil
        msg = Object.new
        msg.define_singleton_method(:send_to) { |dest| sent_to = dest }
        CZTop::Message.stub(:coerce, ->(_) { msg }) do
          zocket << content
        end
        assert_same zocket, sent_to
      end

      it 'returns self' do
        msg = Object.new
        msg.define_singleton_method(:send_to) { |_| nil }
        CZTop::Message.stub(:coerce, ->(_) { msg }) do
          assert_same zocket, zocket << content
        end
      end
    end
  end


  describe '#receive' do
    describe 'given a sent content' do
      let(:content) { 'foobar' }

      it 'receives the content' do
        msg = Object.new
        CZTop::Message.stub(:receive_from, ->(_) { msg }) do
          assert_same msg, zocket.receive
        end
      end
    end
  end


  describe '#read_timeout' do
    let(:req) { CZTop::Socket::REQ.new }


    describe 'with no rcvtimeout set' do
      before do
        assert_equal(-1, req.options.rcvtimeo)
      end

      it 'returns nil' do
        assert_nil req.read_timeout
      end
    end

    # NOTE: 0 would mean non-block (EAGAIN), but that's obsolete with Async
    describe 'with no rcvtimeout=0' do
      before do
        req.options.rcvtimeo = 0
      end

      it 'returns nil' do
        assert_nil req.read_timeout
      end
    end


    describe 'with rcvtimeout set' do
      before do
        req.options.rcvtimeo = 10 # ms
      end

      it 'returns timeout in seconds' do
        assert_equal 0.01, req.read_timeout
      end
    end
  end


  describe '#write_timeout' do
    let(:req) { CZTop::Socket::REQ.new }


    describe 'with no sndtimeout set' do
      before do
        assert_equal(-1, req.options.sndtimeo)
      end

      it 'returns nil' do
        assert_nil req.write_timeout
      end
    end

    # NOTE: 0 would mean non-block (EAGAIN), but that's obsolete with Async
    describe 'with sndtimeout=0' do
      before do
        req.options.sndtimeo = 0
      end

      it 'returns nil' do
        assert_nil req.write_timeout
      end
    end


    describe 'with sndtimeout set' do
      before do
        req.options.sndtimeo = 10
      end

      it 'returns timeout in seconds' do
        assert_equal 0.01, req.write_timeout
      end
    end
  end


  describe 'Async with Fiber Scheduler' do
    require 'async'

    i = 0
    let(:endpoint) { "inproc://async_endpoint_socket_spec_reqrep_#{i += 1}" }
    let(:req)     { CZTop::Socket::REQ.new(endpoint) }
    let(:rep)     { CZTop::Socket::REP.new(endpoint) }
    before { req; rep } # eagerly evaluate

    it 'can send and receive' do
      Async do |task|
        task.async do |_task|
          msg = rep.receive
          word, = msg.to_a
          rep << word.upcase
        end

        task.async do |_task|
          req << 'hello'
          response, = req.receive.to_a
          assert_equal 'HELLO', response
        end
      end
    end


    describe '#wait_readable' do
      describe 'if readable' do
        it 'returns true' do
          Async do
            req << 'foo'
            sleep 0.01 until rep.readable?
            assert_equal true, rep.wait_readable
          end
        end
      end


      describe 'if not readable' do
        it 'waits' do
          Async do |task|
            task.async do
              sleep 0.05
              req << 'bar'
            end

            assert rep.wait_readable
          end
        end


        describe 'when timed out' do
          it 'raises IO::TimeoutError' do
            Async do |_task|
              t0 = Time.now

              assert_raises IO::TimeoutError do
                rep.wait_readable 0.05
              end

              t1 = Time.now
              assert_in_delta 0.05, t1 - t0, 0.05
            end
          end
        end
      end
    end


    describe '#wait_writable' do
      describe 'if writable' do
        it 'returns true' do
          Async do
            sleep 0.01 until req.writable?
            assert_equal true, req.wait_writable
          end
        end
      end


      describe 'if not writable' do
        before do
          refute_operator rep, :writable?
        end

        it 'waits' do
          rep.stub(:wait_for_fd_signal, ->(*) { raise StandardError }) do
            assert_raises(StandardError) do
              rep.wait_writable
            end
          end
        end


        describe 'when not timed out' do
          it 'returns true' do
            Async do |task|
              task.async do
                sleep 0.05
                req << 'bar'
              end

              task.async do
                rep.receive
              end

              t0 = Time.now
              assert rep.wait_writable
              t1 = Time.now

              assert_in_delta 0.05, t1 - t0, 0.05
            end
          end
        end


        describe 'when timed out' do
          it 'raises IO::TimeoutError' do
            Async do |_task|
              t0 = Time.now

              assert_raises IO::TimeoutError do
                rep.wait_writable 0.05
              end

              t1 = Time.now
              assert_in_delta 0.05, t1 - t0, 0.05
            end
          end
        end
      end
    end


    describe '#wait_for_fd_signal' do
      let(:req) { CZTop::Socket::REQ.new }

      it 'waits for readability on ZMQ FD' do
        waited = false
        io = Object.new
        io.define_singleton_method(:wait_readable) { |*| waited = true; nil }
        req.stub(:to_io, io) do
          req.wait_for_fd_signal
        end
        assert waited
      end

      it 'memoizes IO object' do
        call_count = 0
        io = Object.new
        io.define_singleton_method(:wait_readable) { |*| nil }
        req.stub(:to_io, ->(*) { call_count += 1; io }) do
          req.wait_for_fd_signal
          req.wait_for_fd_signal
          req.wait_for_fd_signal
        end
        assert_equal 1, call_count
      end


      describe 'with small timeout' do
        it 'uses that timeout' do
          received_timeout = nil
          io = Object.new
          io.define_singleton_method(:wait_readable) { |t = nil| received_timeout = t; nil }
          req.stub(:to_io, io) do
            req.wait_for_fd_signal 0.05
          end
          assert_equal 0.05, received_timeout
        end
      end


      describe 'with large timeout' do
        it 'uses reasonably small timeout' do
          received_timeout = nil
          io = Object.new
          io.define_singleton_method(:wait_readable) { |t = nil| received_timeout = t; nil }
          req.stub(:to_io, io) do
            req.wait_for_fd_signal 10
          end
          assert received_timeout < 1.0
        end
      end


      describe 'with no timeout' do
        it 'still uses a timeout' do
          received_timeout = nil
          io = Object.new
          io.define_singleton_method(:wait_readable) { |t = nil| received_timeout = t; nil }
          req.stub(:to_io, io) do
            req.wait_for_fd_signal
          end
          assert_kind_of Numeric, received_timeout
        end
      end
    end


    describe 'with rcvtimeo' do
      before do
        req.options.rcvtimeo = 30
        assert_equal 30, req.options.rcvtimeo
      end

      it 'will raise TimeoutError' do
        Async do
          assert_raises ::IO::TimeoutError do
            req.receive
          end
        end
      end
    end


    describe 'with sndtimeo' do
      before do
        rep.options.sndtimeo = 30
        assert_equal 30, rep.options.sndtimeo
      end

      it 'will raise TimeoutError' do
        Async do
          assert_raises ::IO::TimeoutError do
            rep << ['foo']
          end
        end
      end
    end
  end if IO.method_defined?(:wait_readable)
end
