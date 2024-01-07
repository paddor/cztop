# frozen_string_literal: true

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
        msg
      when String, Frame, Array
        new(msg)
      else
        raise ArgumentError, format('cannot coerce message: %p', msg)
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
    #
    # @note Do NOT use this {Message} anymore afterwards. Its native
    #   counterpart will have been destroyed.
    #
    # @param destination [Socket, Actor] where to send this message to
    # @return [void]
    #
    # @raise [IO::EAGAINWaitWritable] if the send timeout has been reached
    #   (see {ZsockOptions::OptionsAccessor#sndtimeo=})
    # @raise [SocketError] if the message can't be routed to the destination
    #   (either if ZMQ_ROUTER_MANDATORY flag is set on a {Socket::ROUTER} socket
    #   and the peer isn't connected or its SNDHWM is reached (see
    #   {ZsockOptions::OptionsAccessor#router_mandatory=}, or if it's
    #   a {Socket::SERVER} socket and there's no connected CLIENT
    #   corresponding
    #   to the given routing ID)
    # @raise [ArgumentError] if the message is invalid, e.g. when trying to
    #   send a multi-part message over a CLIENT/SERVER socket
    # @raise [SystemCallError] for any other error code set after +zmsg_send+
    #   returns with failure. Please report as bug.
    #
    def send_to(destination)
      destination.wait_writable if Fiber.scheduler

      rc = Zmsg.send(ffi_delegate, destination)
      return if rc.zero?

      raise_zmq_err
    rescue Errno::EAGAIN
      raise IO::EAGAINWaitWritable
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
      source.wait_readable if Fiber.scheduler

      delegate = Zmsg.recv(source)
      return from_ffi_delegate(delegate) unless delegate.null?

      HasFFIDelegate.raise_zmq_err
    rescue Errno::EAGAIN
      raise IO::EAGAINWaitReadable
    end


    # Append a frame to this message.
    # @param frame [String, Frame] what to append
    # @raise [ArgumentError] if frame has an invalid type
    # @raise [SystemCallError] if this fails
    # @note If you provide a {Frame}, do NOT use that frame afterwards
    #   anymore, as its native counterpart will have been destroyed.
    # @return [self] so it can be chained
    def <<(frame)
      case frame
      when String
        # NOTE: can't use addstr because the data might be binary
        mem = FFI::MemoryPointer.from_string(frame)
        rc  = ffi_delegate.addmem(mem, mem.size - 1) # without NULL byte
      when Frame
        rc = ffi_delegate.append(frame.ffi_delegate)
      else
        raise ArgumentError, format('invalid frame: %p', frame)
      end
      raise_zmq_err unless rc.zero?
      self
    end


    # Prepend a frame to this message.
    # @param frame [String, Frame] what to prepend
    # @raise [ArgumentError] if frame has an invalid type
    # @raise [SystemCallError] if this fails
    # @note If you provide a {Frame}, do NOT use that frame afterwards
    #   anymore, as its native counterpart will have been destroyed.
    # @return [void]
    def prepend(frame)
      case frame
      when String
        # NOTE: can't use pushstr because the data might be binary
        mem = FFI::MemoryPointer.from_string(frame)
        rc  = ffi_delegate.pushmem(mem, mem.size - 1) # without NULL byte
      when Frame
        rc = ffi_delegate.prepend(frame.ffi_delegate)
      else
        raise ArgumentError, format('invalid frame: %p', frame)
      end
      raise_zmq_err unless rc.zero?
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
      ffi_delegate = ffi_delegate()
      frame        = ffi_delegate.first
      return [] if frame.null?

      arr          = [frame.data.read_bytes(frame.size)]
      while (frame = ffi_delegate.next) && !frame.null?
        arr << frame.data.read_bytes(frame.size)
      end

      arr
    end


    # Inspects this {Message}.
    # @return [String] shows class, number of frames, content size, and
    #   content (only if it's up to 200 bytes)
    def inspect
      format('#<%s:0x%x frames=%i content_size=%i content=%s>', self.class, to_ptr.address, size, content_size,
             content_size <= 500 ? to_a.inspect : '[...]')
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
    # @raise [ArgumentError] if new routing ID is not an Integer
    # @raise [RangeError] if new routing ID is out of +uint32_t+ range
    # @return [new_routing_id]
    def routing_id=(new_routing_id)
      raise ArgumentError unless new_routing_id.is_a? Integer

      # need to raise manually, as FFI lacks this feature.
      # @see https://github.com/ffi/ffi/issues/473
      raise RangeError if new_routing_id.negative?

      ffi_delegate.set_routing_id(new_routing_id)
    end

  end
end
