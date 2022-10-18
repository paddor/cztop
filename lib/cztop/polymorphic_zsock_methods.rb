# frozen_string_literal: true

module CZTop
  # These are methods that can be used on a {Socket} as well as an {Actor}.
  # @see http://api.zeromq.org/czmq3-0:zsock
  module PolymorphicZsockMethods

    # Sends a signal.
    # @param status [Integer] signal (0-255)
    def signal(status = 0)
      ::CZMQ::FFI::Zsock.signal(ffi_delegate, status)
    end


    # Waits for a signal.
    # @return [Integer] the received signal
    def wait
      ::CZMQ::FFI::Zsock.wait(ffi_delegate)
    end


    # Set socket to use unbounded pipes (HWM=0); use this in cases when you are
    # totally certain the message volume can fit in memory.
    def set_unbounded
      ::CZMQ::FFI::Zsock.set_unbounded(ffi_delegate)
    end

  end
end
