# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::Writable do
  describe '#send' do
    i = 0
    let(:endpoint) { "inproc://writable_send_spec_#{i += 1}" }
    let(:push)     { CZTop::Socket::PUSH.new(endpoint) }
    let(:pull)     { CZTop::Socket::PULL.new(endpoint) }

    before do
      push.options.sndtimeo = 100
      pull.options.rcvtimeo = 100
    end

    it 'sends a string' do
      push.send('hello')
      assert_equal ['hello'], pull.receive
    end

    it 'sends an array' do
      push.send(%w[hello world])
      assert_equal %w[hello world], pull.receive
    end

    it 'returns self' do
      assert_same push, push.send('hello')
      pull.receive # drain
    end

    it 'is aliased as #<<' do
      assert_equal push.method(:send).unbind, push.method(:<<).unbind
    end

    it 'raises on empty array' do
      assert_raises(ArgumentError) { push.send([]) }
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
    let(:endpoint) { "inproc://async_writable_spec_#{i += 1}" }
    let(:req)      { CZTop::Socket::REQ.new(endpoint) }
    let(:rep)      { CZTop::Socket::REP.new(endpoint) }
    before { req; rep } # eagerly evaluate


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

              t0 = Time.now
              rep.receive
              assert rep.wait_writable
              t1 = Time.now

              assert_in_delta 0.05, t1 - t0, 0.04
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
              assert_in_delta 0.05, t1 - t0, 0.04
            end
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
  end
end
