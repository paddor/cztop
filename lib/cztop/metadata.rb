require 'set'

module CZTop
  # Useful to encode and decode metadata as defined by ZMTP.
  #
  # ABNF:
  #
  #   metadata = *property
  #   property = name value
  #   name = OCTET 1*255name-char
  #   name-char = ALPHA | DIGIT | "-" | "_" | "." | "+"
  #   value = 4OCTET *OCTET       ; Size in network byte order
  #
  # @see https://rfc.zeromq.org/spec:23/ZMTP
  class Metadata
    VALUE_MAXLEN = 2**31-1

    # Raised when decoding malformed metadata.
    class InvalidData < StandardError
    end

    # regular expression used to validate property names
    NAME_REGEX = /\A[[:alnum:]_.+-]{1,255}\Z/.freeze


    # @param metadata [Hash<Symbol, #to_s>]
    # @raise [ArgumentError] when properties have an invalid, too long, or
    #   duplicated name, or when a value is too long
    # @return [String]
    def self.dump(metadata)
      ic_names = Set.new
      metadata.map do |k, v|
        ic_name = k.to_sym.downcase
        if ic_names.include?(ic_name)
          raise ArgumentError, "property #{k.inspect}: duplicate name"
        else
          ic_names << ic_name
        end
        name = k.to_s
        if NAME_REGEX !~ name
          raise ArgumentError, "property #{k.inspect}: invalid name"
        end
        value = v.to_s
        if value.bytesize > VALUE_MAXLEN
          raise ArgumentError, "property #{k.inspect}: value too long"
        end
        [name.size, name, value.bytesize, value].pack("CA*NA*")
      end.join
    end

    # @param data [String, Frame, #to_s] the data representing the metadata
    # @return [Hash]
    def self.load(data)
      properties = {}
      consumed = 0
      while consumed < data.bytesize # while there are bytes to read
        # read property name
        name_length = data.byteslice(consumed).unpack("C").first # never nil
        raise InvalidData, "zero-length property name" if name_length.zero?
        name = data.byteslice(consumed + 1, name_length)
        raise InvalidData, "incomplete name" if name.bytesize != name_length
        name_sym = name.to_sym.downcase
        if properties.has_key?(name_sym)
          raise InvalidData, "property #{name.inspect}: duplicate name"
        end
        consumed += 1 + name.bytesize

        # read property value
        value_length = data.byteslice(consumed, 4).unpack("N").first or
          raise InvalidData, "incomplete length"
        value = data.byteslice(consumed + 4, value_length)
        raise InvalidData, "incomplete value" if value.bytesize != value_length
        consumed += 4 + value.bytesize

        # remember
        properties[name_sym] = value
      end
      new(properties)
    end

    # @param properties [Hash<Symbol, String>] the properties as loaded by
    #   {load}
    def initialize(properties)
      @properties = properties
    end

    # Gets the value corresponding to a property name. The case of the name
    # is insignificant.
    # @param name [Symbol, String] the property name
    # @return [String] the value
    def [](name)
      @properties[name.to_sym.downcase]
    end

    # @return [Hash<Symbol, String] all properties
    def to_h
      @properties
    end
  end
end
