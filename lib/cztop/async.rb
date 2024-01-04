# frozen_string_literal: true

require 'cztop'
require 'async/io'

module Async
  module IO

    # Wrapper for CZTop sockets.
    #
    # @example
    #   Async do |task|
    #     socket = CZTop::Socket::REP.new("ipc:///tmp/req_rep_example")
    #     socket.options.rcvtimeo = 3
    #     io = Async::IO.try_convert socket
    #     msg = io.receive
    #     io << msg.to_a.map(&:upcase)
    #   end

    class CZTopSocket < Generic
      wraps ::CZTop::Socket::REQ
      wraps ::CZTop::Socket::REP
      wraps ::CZTop::Socket::PAIR
      wraps ::CZTop::Socket::ROUTER
      wraps ::CZTop::Socket::DEALER
      wraps ::CZTop::Socket::PUSH
      wraps ::CZTop::Socket::PULL
      wraps ::CZTop::Socket::PUB
      wraps ::CZTop::Socket::SUB
      wraps ::CZTop::Socket::XPUB
      wraps ::CZTop::Socket::XSUB


      # @see {CZTop::SendReceiveMethods#receive}
      def receive
        wait_readable
        @io.receive
      end


      # @see {CZTop::SendReceiveMethods#<<}
      def <<(...)
        wait_writable
        @io.<<(...)
      end


      # Waits for socket to become readable.
      def wait_readable(timeout = read_timeout)
        @io_fd ||= ::IO.for_fd @io.fd, autoclose: false

        if timeout
          timeout_at = now + timeout

          while true
            @io_fd.wait_readable(timeout)
            break if @io.readable?
            raise ::IO::TimeoutError if now >= timeout_at
          end
        else
          @io_fd.wait_readable until @io.readable?
        end
      end


      # Waits for socket to become writable.
      def wait_writable(timeout = write_timeout)
        @io_fd ||= ::IO.for_fd @io.fd, autoclose: false

        if timeout
          timeout_at = now + timeout

          while true
            @io_fd.wait_writable(timeout)
            break if @io.writable?
            raise ::IO::TimeoutError if now >= timeout_at
          end
        else
          @io_fd.wait_writable until @io.writable?
        end
      end


      # @return [Float, nil] the timeout in seconds used by {IO#wait_readable}
      def read_timeout
        timeout = @io.options.rcvtimeo

        if timeout <= 0
          timeout = nil
        else
          timeout = timeout.to_f / 1000
        end

        timeout
      end


      # @return [Float, nil] the timeout in seconds used by {IO#wait_writable}
      def write_timeout
        timeout = @io.options.sndtimeo

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
end