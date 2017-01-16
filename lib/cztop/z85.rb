module CZTop
  # Represents a CZMQ::FFI::Zarmour in Z85 mode.
  #
  # Use this class to encode to and from the Z85 encoding scheme.
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
      ffi_delegate.set_mode(CZMQ::FFI::Zarmour::MODE_Z85)
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
      zchunk = ffi_delegate.decode(input)
      raise_zmq_err if zchunk.null?
      decoded_string = zchunk.data.read_string(zchunk.size - 1)
      return decoded_string
    end
  end
end
