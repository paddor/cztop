# frozen_string_literal: true

module CZTop
  class Socket
    # Read capability for ZMQ sockets.
    module Readable

      include FdWait

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
      # @raise [IO::TimeoutError] if timeout has been reached
      #
      def wait_readable(timeout = read_timeout)
        wait_for_socket_state(:readable?, timeout)
      end


      # @return [Float, nil] the timeout in seconds used by {#wait_readable}
      def read_timeout
        timeout = options.rcvtimeo

        if timeout <= 0
          timeout = nil
        else
          timeout = timeout.to_f / 1000
        end

        timeout
      end
    end
  end
end
