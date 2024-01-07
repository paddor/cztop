# frozen_string_literal: true

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


    # Waits for socket to become readable.
    # @param timeout [Numeric, nil] timeout in seconds
    # @return [true] if readable within timeout
    # @raise [IO::EAGAINWaitReadable, IO::TimeoutError] if timeout has been reached
    def wait_readable(timeout = read_timeout)
      return true if readable?

      @fd_io ||= to_io

      if timeout
        timeout_at = now + timeout

        while true
          @fd_io.wait_readable(timeout)
          break if readable? # NOTE: ZMQ FD can't be trusted
          raise ::IO::TimeoutError if now >= timeout_at
        end
      else
        @fd_io.wait_readable until readable?
      end

      true
    end


    # Waits for socket to become writable.
    # @param timeout [Numeric, nil] timeout in seconds
    # @return [true] if writable within timeout
    # @raise [IO::EAGAINWaitReadable, IO::TimeoutError] if timeout has been reached
    def wait_writable(timeout = write_timeout)
      return true if writable?

      @fd_io ||= to_io

      if timeout
        timeout_at = now + timeout

        while true
          @fd_io.wait_writable(timeout)
          break if writable? # NOTE: ZMQ FD can't be trusted
          raise ::IO::TimeoutError if now >= timeout_at
        end
      else
        @fd_io.wait_writable until writable?
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
