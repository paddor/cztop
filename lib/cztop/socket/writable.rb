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
      #   {ZsockOptions#send_timeout=})
      # @return [self]
      #
      def send(message)
        parts = message.is_a?(Array) ? message : [message]
        raise ArgumentError, 'message has no parts' if parts.empty?

        # Fast path: nonblock send (no GVL release)
        return self if send_nonblock(parts)

        # Slow path: FD poll → blocking send
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


      private


      # Tries a nonblocking send via zframe_send with ZFRAME_DONTWAIT.
      # @param parts [Array<String>] message parts
      # @return [Boolean] true if sent, false if would block
      #
      def send_nonblock(parts)
        sock_ptr = to_ptr
        pp = _zframe_pp
        last_idx = parts.size - 1

        parts.each_with_index do |part, i|
          str = part.to_s
          frame = CZMQ::FFI.zframe_new_s(str, str.bytesize)
          return false if frame.null?

          flags = CZMQ::FFI::ZFRAME_DONTWAIT
          flags |= CZMQ::FFI::ZFRAME_MORE if i < last_idx

          pp.write_pointer(frame)
          rc = CZMQ::FFI.zframe_send(pp, sock_ptr, flags)
          unless rc.zero?
            CZMQ::FFI.zframe_destroy(pp)
            return false
          end
        end
        true
      end
    end
  end
end
