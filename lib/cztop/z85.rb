module CZTop
  # Represents a CZMQ::FFI::Zarmour in Z85 mode.
  #
  # Use this class to encode to and from the Z85 encoding algorithm.
  # @see http://rfc.zeromq.org/spec:32
  class Z85
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods

    class << self
      # Same as {Z85#encode}, but without the need to create an instance
      # first.
      #
      # @param input [String] possibly binary input data
      # @return [String] Z85 encoded data as ASCII string
      # @raise [ArgumentError] if input length isn't divisible by 4 with no
      #   remainder
      # @raise [SystemCallError] if this fails
      def encode(input)
        default.encode(input)
      end

      # Same as {Z85#decode}, but without the need to create an instance
      # first.
      #
      # @param input [String] Z85 encoded data
      # @return [String] original data as binary string
      # @raise [ArgumentError] if input length isn't divisible by 5 with no
      #   remainder
      # @raise [SystemCallError] if this fails
      def decode(input)
        default.decode(input)
      end

      private

      # Default instance of {Z85}.
      # @return [Z85] memoized default instance
      def default
        @default ||= Z85.new
      end
    end

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
      raise_zmq_err if ptr.null?
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
        raise_zmq_err if buffer_ptr.null?
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
    # If the data to be encoded is empty (0 bytes), it is encoded to the empty
    # string, just like in Z85.
    #
    # Otherwise, a length information is prepended and, if needed, padding (1,
    # 2, or 3 NULL bytes) is appended to bring the resulting blob to
    # a multiple of 4 bytes.
    #
    # The length information is encoded similarly to lengths of messages
    # (frames) in ZMTP. Up to 127 bytes, the data's length is encoded with
    # a single byte (specifically, with the 7 least significant bits in it).
    #
    #   +--------+-------------------------------+------------+
    #   | length |              data             |   padding  |
    #   | 1 byte |        up to 127 bytes        |  0-3 bytes |
    #   +--------+-------------------------------+------------+
    #
    # If the data is 128 bytes or more, the most significant bit will be set
    # to indicate that fact, and a 64 bit unsigned integer in network byte
    # order is appended after this first byte to encode the length of the
    # data.  This means that up to 16EiB (exbibytes) can be encoded, which
    # will be enough for the foreseeable future.
    #
    #   +--------+-----------+----------------------------------+------------+
    #   |  big?  |   length  |                data              |   padding  |
    #   | 1 byte |  8 bytes  |      128 bytes or much more      |  0-3 bytes |
    #   +--------+-----------+----------------------------------+------------+
    #
    # The resulting blob is encoded using {CZTop::Z85#encode}.
    # {CZTop::Z85#decode} does the inverse.
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
        if length < 1<<7 # up to 127 bytes
          encoded_length = [length].pack("C")

        else # larger input
          low = length & 0xFFFFFFFF
          high = (length >> 32) & 0xFFFFFFFF
          encoded_length = [ 1<<7, high, low ].pack("CNN")
        end
        padding = "\0" * ((4 - ((length+1) % 4)) % 4)
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
        decoded = super
        length = decoded.byteslice(0, 1).unpack("C")[0]
        if (1<<7 & length).zero? # up to 127 bytes
          decoded = decoded.byteslice(1, length) # extract payload

        else # larger input
          length = decoded.byteslice(1, 8).unpack("NN")
                     .inject(0) { |sum, i| (sum << 32) + i }
          decoded = decoded.byteslice(9, length) # extract payload
        end
        raise ArgumentError, "input truncated" if decoded.bytesize < length
        return decoded
      end
    end
  end
end
