module CZTop
  # Represents a CZMQ::FFI::Zmsg.
  class Message
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ::CZMQ::FFI

    # Coerces an object into a {Message}.
    # @param msg [Message, String, Frame, Array<String>, Array<Frame>]
    # @return [Message]
    # @raise [ArgumentError] if it can't be coerced
    def self.coerce(msg)
      case msg
      when Message
        return msg
      when String, Frame, Array
        return new(msg)
      else
        raise ArgumentError, "cannot coerce message: %p" % msg
      end
    end

    # @param parts [String, Frame, Array<String>, Array<Frame>] initial parts
    #   of the message
    def initialize(parts = nil)
      attach_ffi_delegate(Zmsg.new)
      Array(parts).each { |part| self << part } if parts
    end

    # @return [Boolean] if this message is empty or not
    def empty?
      content_size.zero?
    end

    # Send {Message} to a {Socket} or {Actor}.
    # @param destination [Socket, Actor] where to send this message to
    # @note Do NOT use this {Message} anymore afterwards. Its native
    #   counterpart will have been destroyed.
    # @return [void]
    # @raise [IO::EAGAINWaitWritable] if the send timeout has been reached
    #   (see {ZsockOptions::OptionsAccessor#sndtimeo=})
    # @raise [SocketError] if the ROUTER_MANDATORY flag is set on
    #   a {Socket::ROUTER} socket and the peer isn't connected or its SNDHWM
    #   is reached (see {ZsockOptions::OptionsAccessor#router_mandatory=})
    # @raise [SystemCallError] for any other error code set after +zmsg_send+
    #   returns with failure. Please report as bug.
    def send_to(destination)
      rc = Zmsg.send(ffi_delegate, destination)
      return if rc == 0

      case errno = ::CZMQ::FFI::Errors.errno
      when Errno::EAGAIN::Errno
        raise IO::EAGAINWaitWritable
      when Errno::EHOSTUNREACH::Errno
        raise SocketError
      else
        # NOTE: If this happens, application code is bad, or this case-list
        # has to be extended. If the errno is known, the corresponding
        # Errno::* exception is automatically constructed. Otherwise, it'll be
        # a normal SystemCallError. In any case, #errno will return the
        # corresponding errno.
        raise SystemCallError.new(::CZMQ::FFI::Errors.strerror, errno)
      end
    end

    # Receive a {Message} from a {Socket} or {Actor}.
    # @param source [Socket, Actor]
    # @return [Message] the newly received message
    # @raise [IO::EAGAINWaitReadable] if the receive timeout has been reached
    #   (see {ZsockOptions::OptionsAccessor#rcvtimeo=})
    # @raise [Interrupt] if interrupted while waiting for a message
    # @raise [SystemCallError] for any other error code set after +zmsg_recv+
    #   returns with failure. Please report as bug.
    def self.receive_from(source)
      delegate = Zmsg.recv(source)
      return from_ffi_delegate(delegate) if !delegate.null?

      case errno = ::CZMQ::FFI::Errors.errno
      when Errno::EAGAIN::Errno
        raise IO::EAGAINWaitReadable
      when Errno::EINTR::Errno
        raise Interrupt
      else
        # NOTE: If this happens, application code is bad, or this case-list
        # has to be extended. If the errno is known, the corresponding
        # Errno::* exception is automatically constructed. Otherwise, it'll be
        # a normal SystemCallError. In any case, #errno will return the
        # corresponding errno.
        raise SystemCallError.new(::CZMQ::FFI::Errors.strerror, errno)
      end
    end

    # Append a frame to this message.
    # @param frame [String, Frame] what to append
    # @raise [ArgumentError] if frame has an invalid type
    # @note If you provide a {Frame}, do NOT use that frame afterwards
    #   anymore, as its native counterpart will have been destroyed.
    # @return [self] so it can be chained
    def <<(frame)
      case frame
      when String
        ffi_delegate.addstr(frame)
      when Frame
        ffi_delegate.append(frame.ffi_delegate)
      else
        raise ArgumentError, "invalid frame: %p" % frame
      end
      self
    end

    # Prepend a frame to this message.
    # @param frame [String, Frame] what to prepend
    # @raise [ArgumentError] if frame has an invalid type
    # @note If you provide a {Frame}, do NOT use that frame afterwards
    #   anymore, as its native counterpart will have been destroyed.
    # @return [void]
    def prepend(frame)
      case frame
      when String
        ffi_delegate.pushstr(frame)
      when Frame
        ffi_delegate.prepend(frame.ffi_delegate)
      else
        raise ArgumentError, "invalid frame: %p" % frame
      end
    end

    # Removes first part from message and returns it as a string.
    # @return [String, nil] first part, if any, or nil
    def pop
      # NOTE: can't use popstr because the data might be binary
      ptr = ffi_delegate.pop
      return nil if ptr.null?
      Frame.from_ffi_delegate(ptr).to_s
    end

    # @return [Integer] size of this message in bytes
    # @see size
    def content_size
      ffi_delegate.content_size
    end

    # Returns all frames as strings in an array. This is useful if for quick
    # inspection of the message.
    # @note It'll read all frames in the message and turn them into Ruby
    #   strings. This can be a problem if the message is huge/has huge frames.
    # @return [Array<String>] all frames
    def to_a
      frames.map(&:to_s)
    end

    # Inspects this {Message}.
    # @return [String] shows class, number of frames, content size, and
    #   content (only if it's up to 200 bytes)
    def inspect
      "#<%s:0x%x frames=%i content_size=%i content=%s>" % [
        self.class,
        to_ptr.address,
        size,
        content_size,
        content_size <= 500 ? to_a.inspect : "[...]"
      ]
    end

    # Return a frame's content.
    # @return [String] the frame's content, if it exists
    # @return [nil] if frame doesn't exist at given index
    def [](frame_index)
      frame = frames[frame_index] or return nil
      frame.to_s
    end

    # Gets the routing ID.
    # @note This only set when the frame came from a {CZTop::Socket::SERVER}
    #   socket.
    # @return [Integer] the routing ID, or 0 if unset
    ffi_delegate :routing_id

    # Sets a new routing ID.
    # @note This is used when the message is sent to a {CZTop::Socket::SERVER}
    #   socket.
    # @param new_routing_id [Integer] new routing ID
    # @raise [RangeError] if new routing ID is out of +uint32_t+ range
    # @return [new_routing_id]
    def routing_id=(new_routing_id)
      # need to raise manually, as FFI lacks this feature.
      # @see https://github.com/ffi/ffi/issues/473
      raise RangeError if new_routing_id < 0
      ffi_delegate.set_routing_id(new_routing_id)
    end
  end
end
