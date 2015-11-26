module CZTop
  class Frame
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
    def send_to(destination, more: false, reuse: false)
      flags = 0; flags |= FLAG_MORE if more; flags |= FLAG_REUSE if reuse
      self_ptr = more ? self : ffi_delegate.__ptr_give_ref
      CZMQ::FFI::Zframe.send(self_ptr, destination, flags)
    end

    # Receive {Frame} from a {Socket}/{Actor}.
    # @note This is low-level. Consider just receiving a {Message}.
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
    def content=(new_content)
      content_ptr = ::FFI::MemoryPointer.from_string(new_content)
      content_size = content_ptr.size
      content_size -= 1 unless new_content.encoding == Encoding::BINARY
      ffi_delegate.reset(content_ptr, content_size)
    end

    # TODO
    def dup
    end

    # TODO
    def more?
    end

    # TODO
    def more=(indicator)
    end

    # TODO
    def ==(other)
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
