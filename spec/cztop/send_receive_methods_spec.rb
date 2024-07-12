# frozen_string_literal: true

require_relative 'spec_helper'

describe CZTop::SendReceiveMethods do
  let(:zocket) do
    o = Object.new
    o.extend CZTop::SendReceiveMethods
    o
  end
  describe '#<<' do
    context 'when sending message' do
      let(:content) { 'foobar' }
      let(:msg) { double('Message') }
      before do
        expect(CZTop::Message).to receive(:coerce).with(content).and_return(msg)
        expect(msg).to receive(:send_to).with(zocket)
      end

      it 'sends content' do
        zocket << content
      end

      it 'returns self' do # so it can be chained
        assert_same zocket, zocket << content
      end
    end
  end

  describe '#receive' do
    context 'given a sent content' do
      let(:content) { 'foobar' }
      it 'receives the content' do
        msg = double
        expect(CZTop::Message).to(
          receive(:receive_from).with(zocket).and_return(msg)
        )
        assert_same msg, zocket.receive
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
    let!(:req)     { CZTop::Socket::REQ.new(endpoint) }
    let!(:rep)     { CZTop::Socket::REP.new(endpoint) }


    it 'can send and receive' do
      Async do |task|
        task.async do |task|
          msg = rep.receive
          word, = msg.to_a
          rep << word.upcase
        end

        task.async do |task|
          req << 'hello'
          response, = req.receive.to_a
          # p response: response
          assert_equal 'HELLO', response
        end
      end
    end


    describe '#wait_readable' do
      context 'if readable' do
        around do |ex|
          Async do
            req << 'foo'
            sleep 0.01 until rep.readable?
            ex.run
          end
        end

        it 'returns true' do
          expect(rep).not_to receive(:wait_for_fd_signal)
          assert_equal true, rep.wait_readable
        end
      end

      context 'if not readable' do
        it 'waits' do
          Async do |task|
            expect(rep).to receive(:wait_for_fd_signal).and_call_original

            task.async do
              sleep 0.05
              req << 'bar'
            end

            assert rep.wait_readable
          end
        end

        context 'when timed out' do
          it 'raises IO::TimeoutError' do
            Async do |task|
              t0 = Time.now

              assert_raises IO::TimeoutError do
                rep.wait_readable 0.05
              end

              t1 = Time.now
              assert_in_delta 0.05, t1 - t0, 0.02
            end
          end
        end
      end
    end


    describe '#wait_writable' do
      context 'if writable' do
        around do |ex|
          Async do
            sleep 0.01 until req.writable?
            ex.run
          end
        end

        it 'returns true' do
          expect(rep).not_to receive(:wait_for_fd_signal)
          assert_equal true, req.wait_writable
        end
      end

      context 'if not writable' do
        before do
          refute_operator rep, :writable?
        end

        it 'waits' do
          expect(rep).to receive(:wait_for_fd_signal) { fail }

          assert_raises StandardError do
            rep.wait_writable
          end
        end

        context 'when not timed out' do
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

              assert_in_delta 0.05, t1 - t0, 0.02
            end
          end
        end

        context 'when timed out' do
          it 'raises IO::TimeoutError' do
            Async do |task|
              t0 = Time.now

              assert_raises IO::TimeoutError do
                rep.wait_writable 0.05
              end

              t1 = Time.now
              assert_in_delta 0.05, t1 - t0, 0.02
            end
          end
        end
      end
    end


    describe '#wait_for_fd_signal' do
      let(:req) { CZTop::Socket::REQ.new }
      let(:io)  { instance_spy ::IO }

      before do
        allow(req).to receive(:to_io) { io }
      end

      it 'waits for readability on ZMQ FD' do
        expect(io).to receive(:wait_readable)
        req.wait_for_fd_signal
      end

      it 'memoizes IO object' do
        expect(req).to receive(:to_io).once
        req.wait_for_fd_signal
        req.wait_for_fd_signal
        req.wait_for_fd_signal
      end

      context 'with small timeout' do
        it 'uses that timeout' do
          expect(io).to receive(:wait_readable).with(0.05)
          req.wait_for_fd_signal 0.05
        end
      end

      context 'with large timeout' do
        it 'uses reasonably small timeout' do
          expect(io).to receive(:wait_readable) do |timeout|
            assert timeout < 1.0
          end
          req.wait_for_fd_signal 10
        end
      end

      context 'with no timeout' do
        it 'still uses a timeout' do
          expect(io).to receive(:wait_readable).with(Numeric)
          req.wait_for_fd_signal
        end
      end
    end


    context 'with rcvtimeo' do
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


    context 'with sndtimeo' do
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
