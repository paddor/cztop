# frozen_string_literal: true

module CZTop
  class Socket
    # Read capability for ZMQ sockets.
    #
    module Readable

      include FdWait

      # Receives a message.
      #
      # @return [Array<String>] message parts
      # @raise [IO::EAGAINWaitReadable, IO::TimeoutError] if receive timeout has been reached (see
      #   {ZsockOptions::OptionsAccessor#rcvtimeo=})
      #
      def receive
        wait_readable

        zmsg = CZMQ::FFI::Zmsg.recv(self)
        HasFFIDelegate.raise_zmq_err if zmsg.null?

        parts = []
        frame = zmsg.first
        while frame
          parts << frame.data.read_bytes(frame.size)
          frame = zmsg.next
        end
        parts
      rescue Errno::EAGAIN
        raise IO::EAGAINWaitReadable
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
      #
      def read_timeout
        timeout = options.rcvtimeo
        return nil if timeout.nil? || timeout == 0

        timeout.to_f / 1000
      end
    end
  end
end
