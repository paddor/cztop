# frozen_string_literal: true

require 'io/wait'

module CZTop
  # These are methods that can be used on a {Socket} as well as an {Actor},
  # but actually just pass through to methods of {Message} (which take
  # a polymorphic reference, in Ruby as well as in C).
  # @see http://api.zeromq.org/czmq3-0:zmsg
  module SendReceiveMethods

    # Sends a message.
    #
    # @param message [Message, String, Array<parts>] the message to send
    # @raise [IO::EAGAINWaitWritable, IO::TimeoutError] if send timeout has been reached (see
    #   {ZsockOptions::OptionsAccessor#sndtimeo=})
    # @raise [Interrupt, ArgumentError, SystemCallError] anything raised by
    #   {Message#send_to}
    # @return [self]
    # @see Message.coerce
    # @see Message#send_to
    def <<(message)
      Message.coerce(message).send_to(self)
      self
    end


    # Receives a message.
    #
    # @return [Message]
    # @raise [IO::EAGAINWaitReadable, IO::TimeoutError] if receive timeout has been reached (see
    #   {ZsockOptions::OptionsAccessor#rcvtimeo=})
    # @raise [Interrupt, ArgumentError, SystemCallError] anything raised by
    #   {Message.receive_from}
    # @see Message.receive_from
    def receive
      Message.receive_from(self)
    end


    # Because ZMQ sockets are edge-triggered, there's a small chance that we miss an edge (race condition). To avoid
    # blocking forever, all waiting on the ZMQ FD is done with this timeout or less.
    #
    # The race condition exists between the calls to {#readable?}/{#writable?} and waiting for the ZMQ FD. If the
    # socke becomes readable/writable during that time, waiting for the FD could block forever without a timeout.
    #
    FD_TIMEOUT = 0.5


    # Waits for the ZMQ file descriptor to signal readiness.
    #
    # ZMQ sockets use a single FD for signaling (always via readability, even
    # for write-readiness). The FD is edge-triggered, so there is a race
    # between checking socket state and waiting on the FD. To avoid blocking
    # forever on a missed edge, the wait is capped at +remaining+ seconds or
    # {FD_TIMEOUT}, whichever is smaller.
    #
    # @param remaining [Float, nil] seconds until caller's deadline, or nil for no deadline
    # @note Only available on Ruby >= 3.2
    #
    def wait_for_fd_signal(remaining = nil)
      @fd_io ||= to_io
      wait = remaining ? [remaining, FD_TIMEOUT].min : FD_TIMEOUT
      @fd_io.wait_readable(wait)
    end


    # ZMQ's edge-triggered FD can signal readiness before the socket is
    # actually ready. This small sleep avoids busy-looping in that case.
    JIFFY = 0.015 # 15 ms


    # Waits for socket to become readable.
    # @param timeout [Numeric, nil] timeout in seconds
    # @return [true] if readable within timeout
    # @raise [IO::TimeoutError] if timeout has been reached
    # @note Only available on Ruby >= 3.2
    #
    def wait_readable(timeout = read_timeout)
      wait_for_socket_state(:readable?, timeout)
    end


    # Waits for socket to become writable.
    # @param timeout [Numeric, nil] timeout in seconds
    # @return [true] if writable within timeout
    # @raise [IO::TimeoutError] if timeout has been reached
    # @note Only available on Ruby >= 3.2
    #
    def wait_writable(timeout = write_timeout)
      wait_for_socket_state(:writable?, timeout)
    end


    # Shared implementation for {#wait_readable} and {#wait_writable}.
    # @param check [Symbol] :readable? or :writable?
    # @param timeout [Numeric, nil] timeout in seconds
    # @return [true]
    # @raise [IO::TimeoutError]
    def wait_for_socket_state(check, timeout)
      return true if __send__(check)

      deadline = now + timeout if timeout

      loop do
        remaining = deadline ? deadline - now : nil
        raise ::IO::TimeoutError if remaining&.negative?

        wait_for_fd_signal(remaining)
        break if __send__(check)

        sleep JIFFY
        break if __send__(check)
      end

      true
    end


    # @return [Float, nil] the timeout in seconds used by {IO#wait_readable}
    def read_timeout
      timeout = options.rcvtimeo

      if timeout <= 0
        timeout = nil
      else
        timeout = timeout.to_f / 1000
      end

      timeout
    end


    # @return [Float, nil] the timeout in seconds used by {IO#wait_writable}
    def write_timeout
      timeout = options.sndtimeo

      if timeout <= 0
        timeout = nil
      else
        timeout = timeout.to_f / 1000
      end

      timeout
    end


    private


    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
