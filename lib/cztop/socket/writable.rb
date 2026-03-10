# frozen_string_literal: true

module CZTop
  class Socket
    # Write capability for ZMQ sockets.
    module Writable

      include FdWait

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
      def send(message)
        Message.coerce(message).send_to(self)
        self
      end

      alias << send


      # Waits for socket to become writable.
      # @param timeout [Numeric, nil] timeout in seconds
      # @return [true] if writable within timeout
      # @raise [IO::TimeoutError] if timeout has been reached
      #
      def wait_writable(timeout = write_timeout)
        wait_for_socket_state(:writable?, timeout)
      end


      # @return [Float, nil] the timeout in seconds used by {#wait_writable}
      def write_timeout
        timeout = options.sndtimeo

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
