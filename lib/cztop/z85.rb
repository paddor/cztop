module CZTop
  class Z85
    include FFIDelegate
    class Error < RuntimeError; end

    def initialize
      attach_ffi_delegate(CZMQ::FFI::Zarmour.new)
      ffi_delegate.set_mode(:mode_z85)
    end

    def encode(string)
      raise ArgumentError if string.bytesize % 4 > 0
      string = string.dup.force_encoding(Encoding::BINARY)
      ptr = ffi_delegate.encode(string, string.bytesize)
      raise Error if ptr.null?
      z85 = ptr.read_string
      z85.encode!(Encoding::ASCII)
      return z85
    end

    def decode(string)
      raise ArgumentError if string.bytesize % 5 > 0
      FFI::MemoryPointer.new(:size_t) do |size_ptr|
        buffer_ptr = ffi_delegate.decode(string, size_ptr)
        raise Error if buffer_ptr.null?
        decoded_string = buffer_ptr.read_string_length(_size(size_ptr) - 1)
        return decoded_string
      end
    end

    def mode
      ffi_delegate.mode_str
    end

    private

    # Gets correct size, depending on the platform.
    # @return [Integer]
    # @see https://github.com/ffi/ffi/issues/398
    # @see https://github.com/ffi/ffi/issues/333
    def _size(size_ptr)
      if size_ptr.size == 8 # 64 bit
        size_ptr.read_uint64
      else
        size_ptr.read_uint32
      end
    end
  end
end
