# frozen_string_literal: true

require 'io/wait'

module CZTop
  class Socket
    # Shared FD polling infrastructure for ZMQ sockets.
    #
    # ZMQ uses a single edge-triggered FD for both read/write signaling.
    # This module provides the low-level wait loop that checks socket
    # readiness and polls the FD.
    module FdWait

      # Because ZMQ sockets are edge-triggered, there's a small chance that we miss an edge (race condition). To avoid
      # blocking forever, all waiting on the ZMQ FD is done with this timeout or less.
      #
      # The race condition exists between the calls to {#readable?}/{#writable?} and waiting for the ZMQ FD. If the
      # socket becomes readable/writable during that time, waiting for the FD could block forever without a timeout.
      #
      FD_TIMEOUT = 0.25


      # ZMQ's edge-triggered FD can signal readiness before the socket is
      # actually ready. This small sleep avoids busy-looping in that case.
      JIFFY = 0.001 # 1 ms


      # Waits for the ZMQ file descriptor to signal readiness.
      #
      # ZMQ sockets use a single FD for signaling (always via readability, even
      # for write-readiness). The FD is edge-triggered, so there is a race
      # between checking socket state and waiting on the FD. To avoid blocking
      # forever on a missed edge, the wait is capped at +remaining+ seconds or
      # {FD_TIMEOUT}, whichever is smaller.
      #
      # @param remaining [Float, nil] seconds until caller's deadline, or nil for no deadline
      #
      def wait_for_fd_signal(remaining = nil)
        @fd_io ||= to_io
        wait = remaining ? [remaining, FD_TIMEOUT].min : FD_TIMEOUT
        @fd_io.wait_readable(wait)
      end


      # Shared implementation for {Readable#wait_readable} and {Writable#wait_writable}.
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


      private


      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
