module CZTop
  # Represents a {CZMQ::FFI::Zframe}.
  class Frame
    # @!parse extend CZTop::FFIDelegate::ClassMethods


    include FFIDelegate

    # Initialize a new {Frame}.
    # @param content [String] initial content
    def initialize(content = nil)
      attach_ffi_delegate(CZMQ::FFI::Zframe.new_empty)
      self.content = content if content
    end

    FLAG_MORE = 1
    FLAG_REUSE = 2
    FLAG_DONTWAIT = 4 # FIXME: Used for ...?

    # Send {Message} to a {Socket}/{Actor}.
    # @param destination [Socket, Actor] where to send this {Message} to
    # @param more [Boolean] are there more {Frame}s to come for the same
    #   {Message}?
    # @param reuse [Boolean] do you wanna send this {Frame} to other
    #   destinations as well?
    # @note If you don't specify +reuse: true+, do NOT use this {Message}
    #   anymore afterwards. Its native counterpart will have been destroyed.
    # @note This is low-level. Consider just sending a {Message}.
    # @return [void]
    def send_to(destination, more: false, reuse: false)
      flags = 0; flags |= FLAG_MORE if more; flags |= FLAG_REUSE if reuse
      self_ptr = more ? self : ffi_delegate.__ptr_give_ref
      CZMQ::FFI::Zframe.send(self_ptr, destination, flags)
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

    # @return [Boolean] if this {Frame} has zero-sized content
    def empty?
      size.zero?
    end

    # Sets new content of this {Frame}.
    # @param new_content [String]
    # @return [void]
    def content=(new_content)
      content_ptr = ::FFI::MemoryPointer.from_string(new_content)
      content_size = content_ptr.size
      content_size -= 1 unless new_content.encoding == Encoding::BINARY
      ffi_delegate.reset(content_ptr, content_size)
    end

    # Duplicates a frame.
    # @return [Frame] new frame with same content
    ffi_delegate :dup

    # @return [Boolean] if the MORE indicator is set
    # @note This happens when reading a frame from a {Socket} or using
    #   {#more=}.
    def more?
      ffi_delegate.more
    end

    # Sets the MORE indicator.
    # @param indicator [Boolean]
    # @note This is NOT used when sending frame to socket.
    # @see #send_to
    # @return [indicator]
    def more=(indicator)
      # TODO
    end

    # Compare to another frame.
    # @param other [Frame]
    # @return [Boolean] if this and the other frame have identical size and
    #   data
    def ==(other)
      ffi_delegate.eq(other)
    end

    # @!attribute [r]
    # @return [Integer] content length in bytes
    ffi_delegate :size

    # @return [String]
    def to_s
      ffi_delegate.data.read_string_length(size)
    end
  end
end
