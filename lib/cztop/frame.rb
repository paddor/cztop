module CZTop
  # Represents a CZMQ::FFI::Zframe.
  class Frame
    # @!parse extend CZTop::HasFFIDelegate::ClassMethods


    include HasFFIDelegate

    class Error < RuntimeError; end

    # Initialize a new {Frame}.
    # @param content [String] initial content
    def initialize(content = nil)
      attach_ffi_delegate(CZMQ::FFI::Zframe.new_empty)
      self.content = content if content
    end

    FLAG_MORE = 1
    FLAG_REUSE = 2
    FLAG_DONTWAIT = 4

    # Send {Message} to a {Socket}/{Actor}.
    # @param destination [Socket, Actor] where to send this {Message} to
    # @param more [Boolean] whether there are more {Frame}s to come for the
    #   same {Message}
    # @param reuse [Boolean] whether this {Frame} will be used to send to
    #   other destinations later
    # @param dontwait [Boolean] whether the operation should be performed in
    #   non-blocking mode
    # @note If you don't specify +reuse: true+, do NOT use this {Frame}
    #   anymore afterwards. Its native counterpart will have been destroyed.
    # @note This is low-level. Consider just sending a {Message}.
    # @return [void]
    # @raise [IO::EAGAINWaitWritable] if dontwait was set and the operation
    #   would have blocked right now
    # @raise [Error] if there was some error. In that case, the native
    #   counterpart still exists and this {Frame} can be reused.
    def send_to(destination, more: false, reuse: false, dontwait: false)
      flags = 0
      flags |= FLAG_MORE if more
      flags |= FLAG_REUSE if reuse
      flags |= FLAG_DONTWAIT if dontwait

      # remember pointer, in case the zframe_t won't be destroyed
      zframe_ptr = ffi_delegate.to_ptr
      ret = CZMQ::FFI::Zframe.send(ffi_delegate, destination, flags)

      if reuse || ret == -1
        # zframe_t hasn't been destroyed yet: avoid memory leak.
        attach_ffi_delegate(CZMQ::FFI::Zframe.__new(zframe_ptr, true))
        # OPTIMIZE: reuse existing Zframe object by redefining its finalizer
      end

      if ret == -1
        if dontwait && FFI.errno == Errno::EAGAIN::Errno
          raise IO::EAGAINWaitWritable
        end

        raise Error
      end
    end

    # Receive {Frame} from a {Socket}/{Actor}.
    # @note This is low-level. Consider just receiving a {Message}.
    # @return [Frame]
    def self.receive_from(source)
      from_ffi_delegate(CZMQ::FFI::Zframe.recv(source))
    end

    # @note This string is always binary. Use String#force_encoding if needed.
    # @return [String] content as string (encoding = Encoding::BINARY)
    def content
      ffi_delegate.data.read_string_length(size)
    end
    alias_method :to_s, :content

    # @return [Boolean] if this {Frame} has zero-sized content
    def empty?
      size.zero?
    end

    # Sets new content of this {Frame}.
    # @param new_content [String]
    # @return [new_content]
    def content=(new_content)
      content_ptr = ::FFI::MemoryPointer.new(new_content.bytesize)
      content_ptr.write_bytes(new_content)
      ffi_delegate.reset(content_ptr, content_ptr.size)
      # NOTE: FFI::MemoryPointer will autorelease
    end

    # Duplicates a frame.
    # @return [Frame] new frame with same content
    def dup
      from_ffi_delegate(ffi_delegate.dup)
    end

    # @return [Boolean] if the MORE indicator is set
    # @note This happens when reading a frame from a {Socket} or using
    #   {#more=}.
    def more?
      ffi_delegate.more == 1
    end

    # Sets the MORE indicator.
    # @param indicator [Boolean]
    # @note This is NOT used when sending frame to socket.
    # @see #send_to
    # @return [indicator]
    def more=(indicator)
      ffi_delegate.set_more(indicator ? 1 : 0)
    end

    # Compare to another frame.
    # @param other [Frame]
    # @return [Boolean] if this and the other frame have identical size and
    #   data
    # @note If you need to compare to a string, as zframe_streq() would do,
    #   just get this frame's content first and compare that to the string.
    #     frame = CZTop::Frame.new("foobar")
    #     frame.to_s == "foobar" #=> true
    # @example
    #   frame1 = Frame.new("foo")
    #   frame2 = Frame.new("foo")
    #   frame3 = Frame.new("bar")
    #   frame1 == frame2    #=> true
    #   frame1 == frame3    #=> false
    # @note The {#more?} flag and the {#routing_id} are ignored.
    def ==(other)
      ffi_delegate.eq(other.ffi_delegate)
    end

    # @return [Integer] content length in bytes
    ffi_delegate :size

    # Gets the routing ID.
    # @note This only set when the frame came from a {CZTop::Socket::SERVER}
    #   socket.
    # @return [Integer] the routing ID, or 0 if unset
    ffi_delegate :routing_id

    # Sets a new routing ID.
    # @note This is used when the frame is sent to a {CZTop::Socket::SERVER}
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
