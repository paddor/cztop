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
      #   {ZsockOptions#recv_timeout=})
      #
      def receive
        # Fast path: nonblock recv (no GVL release)
        parts = recv_nonblock
        return parts if parts

        # Slow path: FD poll → blocking recv
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


      private


      # Tries a nonblocking receive via zframe_recv_nowait.
      # @return [Array<String>, nil] message parts, or nil if not ready
      #
      def recv_nonblock
        sock_ptr = to_ptr
        frame = CZMQ::FFI.zframe_recv_nowait(sock_ptr)
        return nil if frame.null?

        pp = _zframe_pp
        parts = []
        loop do
          parts << CZMQ::FFI.zframe_data(frame).read_bytes(CZMQ::FFI.zframe_size(frame))
          more = CZMQ::FFI.zframe_more(frame) == 1
          pp.write_pointer(frame)
          CZMQ::FFI.zframe_destroy(pp)
          break unless more
          frame = CZMQ::FFI.zframe_recv_nowait(sock_ptr)
          break if frame.null?
        end
        parts
      end
    end
  end
end
