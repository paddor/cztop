module CZTop
  class Z85
    include NativeDelegate
    def initialize
      self.delegate = CZMQ::FFI::Zarmour.new
      self.delegate.set_mode(:z85)
    end

    def encode(string)
      string = string.dup.force_encoding(Encoding::ASCII_8BIT)
      string << ("\0" * ((4 - (string.bytesize % 4)) % 4)) # pad
      warn "padded string before encoding: %p" % string
      delegate.encode(string, string.bytesize) or raise
    end

    def decode(string)
      warn "decoding from string: %p" % string
      raise ArgumentError if string.bytesize % 5 > 0
      FFI::MemoryPointer.new(:size_t) do |size_ptr|
        buffer_ptr = delegate.decode(string, size_ptr)
        raise "error" if buffer_ptr.null?
        size = size_ptr.size == 8 ? size_ptr.read_uint64 : size_ptr.read_uint32
        warn "decoded string is %i bytes long" % size
        return buffer_ptr.read_string_length(size - 1)
      end
    end

    def mode
      delegate.mode_str
    end
  end
end
