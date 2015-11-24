module CZTop
  class Frame
    include NativeDelegate

    def size
      @delegate.size
    end

    def to_s
      @delegate.data.read_string_length(size)
    end
  end
end
