# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::Readable do
  describe '#receive' do
    i = 0
    let(:endpoint) { "inproc://readable_receive_spec_#{i += 1}" }
    let(:push)     { CZTop::Socket::PUSH.new(endpoint) }
    let(:pull)     { CZTop::Socket::PULL.new(endpoint) }

    before do
      push.options.sndtimeo = 100
      pull.options.rcvtimeo = 100
    end

    it 'returns an Array of Strings' do
      push << 'hello'
      msg = pull.receive
      assert_kind_of Array, msg
      assert_equal ['hello'], msg
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


  describe 'Async with Fiber Scheduler' do
    require 'async'

    i = 0
    let(:endpoint) { "inproc://async_readable_spec_#{i += 1}" }
    let(:req)     { CZTop::Socket::REQ.new(endpoint) }
    let(:rep)     { CZTop::Socket::REP.new(endpoint) }
    before { req; rep } # eagerly evaluate


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
              assert_in_delta 0.05, t1 - t0, 0.04
            end
          end
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
  end
end
