# frozen_string_literal: true

begin
  require 'io/wait'
rescue LoadError
end

unless defined? IO::TimeoutError
  # Define this to avoid NameError on Ruby < 3.2
  class IO::TimeoutError < IOError
  end
end

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


    # @note Only available on Ruby >= 3.2
    #
    def wait_for_fd_signal(timeout = nil)
      @fd_io ||= to_io

      if timeout
        if timeout > FD_TIMEOUT
          timeout = FD_TIMEOUT
        end
      else
        timeout = FD_TIMEOUT
      end

      # NOTE: always wait for readability on ZMQ FD
      @fd_io.wait_readable timeout
    end if IO.method_defined?(:wait_readable)


    # Sometimes the ZMQ FD just insists on readiness. To avoid hogging the CPU, a sleep of this many seconds is
    # included in the tight loop.
    JIFFY = 0.015 # 15 ms


    # Waits for socket to become readable.
    # @param timeout [Numeric, nil] timeout in seconds
    # @return [true] if readable within timeout
    # @raise [IO::EAGAINWaitReadable, IO::TimeoutError] if timeout has been reached
    # @raise [CZMQ::FFI::Zsock::DestroyedError] if socket has already been destroyed
    # @note Only available on Ruby >= 3.2
    #
    def wait_readable(timeout = read_timeout)
      return true if readable?

      timeout_at = now + timeout if timeout

      while true
        # p wait_readable: self, timeout: timeout

        wait_for_fd_signal timeout
        break if readable? # NOTE: ZMQ FD can't be trusted
        raise ::IO::TimeoutError if timeout_at && now >= timeout_at

        sleep JIFFY # HACK
        break if readable? # NOTE: ZMQ FD is edge-triggered. Check again before blocking.
      end

      true
    end if IO.method_defined?(:wait_readable)


    # Waits for socket to become writable.
    # @param timeout [Numeric, nil] timeout in seconds
    # @return [true] if writable within timeout
    # @raise [IO::EAGAINWaitReadable, IO::TimeoutError] if timeout has been reached
    # @raise [CZMQ::FFI::Zsock::DestroyedError] if socket has already been destroyed
    # @note Only available on Ruby >= 3.2
    #
    def wait_writable(timeout = write_timeout)
      return true if writable?

      timeout_at = now + timeout if timeout

      while true
        # p wait_writable: self, timeout: timeout

        wait_for_fd_signal timeout
        break if writable? # NOTE: ZMQ FD can't be trusted
        raise ::IO::TimeoutError if timeout_at && now >= timeout_at

        sleep JIFFY # HACK
        break if writable? # NOTE: ZMQ FD is edge-triggered. Check again before blocking.
      end

      true
    end if IO.method_defined?(:wait_readable)


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
