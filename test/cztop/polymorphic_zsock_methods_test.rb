# frozen_string_literal: true

require_relative 'test_helper'

describe CZTop::PolymorphicZsockMethods do
  i = 0
  let(:endpoint) { "inproc://send_receive_method_spec_#{i += 1}" }
  let(:socket_a) { CZTop::Socket::PAIR.new("@#{endpoint}") }
  let(:socket_b) { CZTop::Socket::PAIR.new(">#{endpoint}") }


  describe 'signals' do
    let(:delegate_b) { socket_b.ffi_delegate }
    let(:status) { 5 }


    describe '#signal' do
      describe 'with signal' do
        it 'sends a signal' do
          called_with = nil
          CZMQ::FFI::Zsock.stub(:signal, ->(*args) { called_with = args }) do
            socket_b.signal(status)
          end
          assert_equal [delegate_b, status], called_with
        end
      end


      describe 'with no signal given' do
        it 'sends signal 0' do
          called_with = nil
          CZMQ::FFI::Zsock.stub(:signal, ->(*args) { called_with = args }) do
            socket_b.signal
          end
          assert_equal [delegate_b, 0], called_with
        end
      end
    end


    describe '#wait' do
      it 'returns the signal status' do
        socket_b.signal(status)
        assert_equal status, socket_a.wait
      end

      it 'fails in a non-blocking Fiber' do
        Fiber.new blocking: false do
          assert_raises NotImplementedError do
            socket_a.wait
          end
        end.resume
      end

      it 'works in a blocking Fiber' do
        signaled = false
        socket_b.signal(status)

        Fiber.new blocking: true do
          socket_a.wait
          signaled = true
        end.resume

        assert signaled
      end
    end
  end


  describe '#set_unbounded' do
    it 'sets sndhwm and rcvhwm to 0' do
      socket_a.set_unbounded
      assert_equal 0, socket_a.options.sndhwm
      assert_equal 0, socket_a.options.rcvhwm
    end
  end
end
