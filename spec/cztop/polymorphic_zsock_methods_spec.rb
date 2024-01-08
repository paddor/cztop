# frozen_string_literal: true

require_relative 'spec_helper'

describe CZTop::PolymorphicZsockMethods do
  i = 0
  let(:endpoint) { "inproc://send_receive_method_spec_#{i += 1}" }
  let(:socket_a) { CZTop::Socket::PAIR.new("@#{endpoint}") }
  let(:socket_b) { CZTop::Socket::PAIR.new(">#{endpoint}") }

  describe 'signals' do
    let(:delegate_b) { socket_b.ffi_delegate }
    let(:status) { 5 }
    describe '#signal' do
      context 'with signal' do
        it 'sends a signal' do
          expect(CZMQ::FFI::Zsock).to receive(:signal).with(delegate_b, status)
          socket_b.signal(status)
        end
      end

      context 'with no signal given' do
        it 'sends signal 0' do
          expect(CZMQ::FFI::Zsock).to receive(:signal).with(delegate_b, 0)
          socket_b.signal
        end
      end
    end

    describe '#wait' do
      When { socket_b.signal(status) }
      Then { status == socket_a.wait }

      it 'fails in a non-blocking Fiber' do
        Fiber.new blocking: false do
          assert_raises NotImplementedError do
            socket_a.wait
          end
        end.resume
      end

      it 'works in a blocking Fiber' do
        signaled = false

        Fiber.new blocking: true do
          socket_a.wait
          signaled = true
        end.resume

        assert signaled
      end
    end
  end

  describe '#set_unbounded' do
    Given(:options) { socket_a.options }
    When { socket_a.set_unbounded }
    Then { options.sndhwm == 0 }
    And { options.rcvhwm == 0 }
  end
end
