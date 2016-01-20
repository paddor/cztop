module CZTop
  # Represents a CZMQ::FFI::Zarmour in Z85 mode.
  #
  # Use this class to encode to and from the Z85 encoding algorithm.
  # @see http://rfc.zeromq.org/spec:32
  class Z85
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods

    def initialize
      attach_ffi_delegate(CZMQ::FFI::Zarmour.new)
      ffi_delegate.set_mode(:mode_z85)
    end

    # Encodes to Z85.
    # @param input [String] possibly binary input data
    # @return [String] Z85 encoded data as ASCII string
    # @raise [ArgumentError] if input length isn't divisible by 4 with no
    #   remainder
    # @raise [SystemCallError] if this fails
    def encode(input)
      raise ArgumentError, "wrong input length" if input.bytesize % 4 > 0
      input = input.dup.force_encoding(Encoding::BINARY)
      ptr = ffi_delegate.encode(input, input.bytesize)
      raise_sys_err if ptr.null?
      z85 = ptr.read_string
      z85.encode!(Encoding::ASCII)
      return z85
    end

    # Decodes from Z85.
    # @param input [String] Z85 encoded data
    # @return [String] original data as binary string
    # @raise [ArgumentError] if input length isn't divisible by 5 with no
    #   remainder
    # @raise [SystemCallError] if this fails
    def decode(input)
      raise ArgumentError, "wrong input length" if input.bytesize % 5 > 0
      FFI::MemoryPointer.new(:size_t) do |size_ptr|
        buffer_ptr = ffi_delegate.decode(input, size_ptr)
        raise_sys_err if buffer_ptr.null?
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

    # Z85 with simple padding. This allows you to {#encode} input of any
    # length.
    #
    # = Encoding Procedure
    #
    # If the data to be encoded isn't empty, its length is prepended as a 64
    # bit unsigned integer in network byte order. Any padding (NULL bytes)
    # needed to bring it up to a multiple of 4 bytes is appended. Padding is
    # always between 0 and 3 bytes. The resulting data is encoded using
    # {CZTop::Z85#encode}. This will result in at least 11 bytes (unless the
    # data to be encoded was empty).
    #
    # If the data to be encoded is empty (0 bytes), it is encoded to the empty
    # string, just like in Z85.
    #
    # @note Warning: This won't be compatible with other implementations of
    #   Z85. Only use this if you really need padding, like when you can't
    #   guarantee the input for {#encode} is always a multiple of 4 bytes.
    #
    class Padded < Z85
      # Encododes to Z85, with padding if needed.
      #
      # If input isn't empty, 8 additional bytes for the encoded length will
      # be prepended. If needed, 1 to 3 bytes of padding will be appended.
      #
      # If input is empty, returns the empty string.
      #
      # @param input [String] possibly binary input data
      # @return [String] Z85 encoded data as ASCII string, including encoded
      #   length and padding
      # @raise [SystemCallError] if this fails
      def encode(input)
        return super if input.empty?
        length = input.bytesize
        low = length & 0xFFFFFFFF
        high = (length >> 32) & 0xFFFFFFFF
        encoded_length = [ high, low ].pack("NN")
        padding = "\0" * ((4 - (length % 4)) % 4)
        super("#{encoded_length}#{input}#{padding}")
      end

      # Decodes from Z85 with padding.
      #
      # @param input [String] Z85 encoded data (including encoded length and
      #   padding, or empty string)
      # @return [String] original data as binary string
      # @raise [ArgumentError] if input is invalid or truncated
      # @raise [SystemCallError] if this fails
      def decode(input)
        return super if input.empty?
        raise ArgumentError, "invalid input" if input.bytesize < 11
        decoded = super
        length = decoded.byteslice(0, 8).unpack("NN")
                   .inject(0) { |sum, i| (sum << 32) + i }
        decoded = decoded.byteslice(8,length) # extract payload
        raise ArgumentError, "input truncated" if decoded.bytesize < length
        return decoded
      end
    end
  end
end
