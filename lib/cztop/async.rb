# frozen_string_literal: true

require 'cztop'
require 'async/io'

module Async
  module IO
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


      def receive
        wait_readable
        @io.receive
      end


      def <<(...)
        wait_writable
        @io.<<(...)
      end


      def wait_readable(timeout = read_timeout)
        puts "Async::IO::CZTopSocket#wait_readable: waiting with timeout=#{timeout}"
        @io_fd ||= ::IO.for_fd @io.fd, autoclose: false

        if timeout
          timeout_at = now + timeout

          while true
            @io_fd.wait_readable(timeout)
            break if @io.readable?
            raise TimeoutError if now >= timeout_at
          end
        else
          @io_fd.wait_readable until @io.readable?
        end
      end


      def wait_writable(timeout = write_timeout)
        puts "Async::IO::CZTopSocket#wait_writable: waiting with timeout=#{timeout}"
        @io_fd ||= ::IO.for_fd @io.fd, autoclose: false

        if timeout
          timeout_at = now + timeout

          while true
            @io_fd.wait_writable(timeout)
            break if @io.writable?
            raise TimeoutError if now >= timeout_at
          end
        else
          @io_fd.wait_writable until @io.writable?
        end
      end


      def read_timeout
        timeout = @io.options.rcvtimeo
        timeout = nil if timeout <= 0
        timeout
      end


      def write_timeout
        timeout = @io.options.sndtimeo
        timeout = nil if timeout <= 0
        timeout
      end


      private


      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
