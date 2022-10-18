# frozen_string_literal: true

# Z85 with simple padding. This allows you to {#encode} input of any
# length.
#
# = Padding Scheme
#
# If the data to be encoded is empty (0 bytes), it is encoded to the empty
# string, just like in Z85.
#
# Otherwise, a small padding sequence of 1 to 4 (identical) bytes is
# appended to the binary data. Its last byte denotes the number of padding
# bytes.  This padding is done even if the length of the binary input is
# a multiple of 4 bytes.  This is similar to PKCS#7 padding.
#
#   +----------------------------------------+------------+
#   |                 binary data            |   padding  |
#   |           any number of bytes          |  1-4 bytes |
#   +----------------------------------------+------------+
#
# The resulting blob is encoded using {CZTop::Z85#encode}.
#
# When decoding, {CZTop::Z85#decode} does the inverse. After decoding, it
# checks the last byte to determine the number of bytes of padding used,
# and chops those off.
#
# @note Warning: Z85 doesn't have a standardized padding procedure. So
#   other implementations won't automatically recognize and chop off the
#   padding. Only use this if you really need padding, like when you can't
#   guarantee the input for {#encode} is always a multiple of 4 bytes.
#
# @see https://en.wikipedia.org/wiki/Padding_(cryptography)#PKCS7
class CZTop::Z85::Padded < CZTop::Z85

  class << self

    # Same as {Z85::Padded#encode}, but without the need to create an
    # instance first.
    #
    # @param input [String] possibly binary input data
    # @return [String] Z85 encoded data as ASCII string, including encoded
    #   length and padding
    # @raise [SystemCallError] if this fails
    def encode(input)
      default.encode(input)
    end


    # Same as {Z85::Padded#decode}, but without the need to create an
    # instance first.
    #
    # @param input [String] Z85 encoded data (including padding, or empty
    #   string)
    # @return [String] original data as binary string
    # @raise [SystemCallError] if this fails
    def decode(input)
      default.decode(input)
    end

    private

    # Default instance of {Z85::Padded}.
    # @return [Z85::Padded] memoized default instance
    def default
      @default ||= CZTop::Z85::Padded.new
    end

  end

  # Encododes to Z85, with padding if needed.
  #
  # @param input [String] possibly binary input data
  # @return [String] Z85 encoded data as ASCII string, including padding
  # @raise [SystemCallError] if this fails
  def encode(input)
    return super if input.empty?

    padding_bytes = 4 - (input.bytesize % 4)

    # if 0, make it 4. we MUST append padding.
    padding_bytes = 4 if padding_bytes.zero?

    # generate and append padding
    padding = [padding_bytes].pack('C') * padding_bytes

    super("#{input}#{padding}")
  end


  # Decodes from Z85 with padding.
  #
  # @param input [String] Z85 encoded data (including padding, or empty
  #   string)
  # @return [String] original data as binary string
  # @raise [SystemCallError] if this fails
  def decode(input)
    return super if input.empty?

    decoded = super

    # last byte contains number of padding bytes
    padding_bytes = decoded.byteslice(-1).ord

    decoded.byteslice(0...-padding_bytes)
  end

end
