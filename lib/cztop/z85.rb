module CZTop
  # Represents a CZMQ::FFI::Zarmour in Z85 mode.
  #
  # Use this class to encode to and from the Z85 encoding algorithm.
  # @see http://rfc.zeromq.org/spec:32
  class Z85
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods

    class Error < RuntimeError; end

    def initialize
      attach_ffi_delegate(CZMQ::FFI::Zarmour.new)
      ffi_delegate.set_mode(:mode_z85)
    end

    # Encodes to Z85.
    # @param input [String] possibly binary input data
    # @return [String] Z85 encoded data as ASCII string
    # @raise [ArgumentError] if input length isn't divisible by 4 with no
    #   remainder
    def encode(input)
      raise ArgumentError if input.bytesize % 4 > 0
      input = input.dup.force_encoding(Encoding::BINARY)
      ptr = ffi_delegate.encode(input, input.bytesize)
      raise Error if ptr.null?
      z85 = ptr.read_string
      z85.encode!(Encoding::ASCII)
      return z85
    end

    # Decodes from Z85.
    # @param input [String] Z85 encoded data
    # @return [String] original data as binary string
    # @raise [ArgumentError] if input length isn't divisible by 5 with no
    #   remainder
    def decode(input)
      raise ArgumentError if input.bytesize % 5 > 0
      FFI::MemoryPointer.new(:size_t) do |size_ptr|
        buffer_ptr = ffi_delegate.decode(input, size_ptr)
        raise Error if buffer_ptr.null?
        decoded_string = buffer_ptr.read_string(_size(size_ptr) - 1)
        return decoded_string
      end
    end

    private

    # Gets correct size, depending on the platform.
    # @return [Integer]
    # @see https://github.com/ffi/ffi/issues/398
    # @see https://github.com/ffi/ffi/issues/333
    def _size(size_ptr)
      if RUBY_ENGINE == "jruby"
        # NOTE: JRuby FFI doesn't have #read_uint64, nor does it have
        # Pointer::SIZE
        return size_ptr.read_ulong_long
      end

      if ::FFI::Pointer::SIZE == 8 # 64 bit
        size_ptr.read_uint64
      else
        size_ptr.read_uint32
      end
    end
  end
end
