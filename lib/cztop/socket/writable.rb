# frozen_string_literal: true

module CZTop
  class Socket
    # Write capability for ZMQ sockets.
    #
    module Writable

      include FdWait

      # Sends a message.
      #
      # @param message [String, Array<String>] the message to send
      # @raise [IO::EAGAINWaitWritable, IO::TimeoutError] if send timeout has been reached (see
      #   {ZsockOptions::OptionsAccessor#sndtimeo=})
      # @return [self]
      #
      def send(message)
        parts = message.is_a?(Array) ? message : [message]
        raise ArgumentError, 'message has no parts' if parts.empty?

        wait_writable

        zmsg = CZMQ::FFI::Zmsg.new
        parts.each do |part|
          rc = zmsg.add_buffer(part.to_s)
          HasFFIDelegate.raise_zmq_err unless rc.zero?
        end

        rc = CZMQ::FFI::Zmsg.send(zmsg, self)
        return self if rc.zero?

        HasFFIDelegate.raise_zmq_err
      rescue Errno::EAGAIN
        raise IO::EAGAINWaitWritable
      end

      alias_method :<<, :send


      # Waits for socket to become writable.
      # @param timeout [Numeric, nil] timeout in seconds
      # @return [true] if writable within timeout
      # @raise [IO::TimeoutError] if timeout has been reached
      #
      def wait_writable(timeout = write_timeout)
        wait_for_socket_state(:writable?, timeout)
      end


      # @return [Float, nil] the timeout in seconds used by {#wait_writable}
      #
      def write_timeout
        timeout = options.sndtimeo
        return nil if timeout.nil? || timeout == 0

        timeout.to_f / 1000
      end
    end
  end
end
