module CZTop
  class Message

    # @return [Integer] number of frames
    # @see content_size
    def size
      frames.count
    end

    # Access to this {Message}'s {Frame}s.
    # @return [Frames]
    def frames
      Frames.new(self)
    end

    # Used to access a {Message}'s {Frame}s.
    class Frames
      include Enumerable

      # @param message [Message]
      def initialize(message)
        @message = message
      end

      # @return [Frame] first frame of Message
      # @return [nil] if there are no frames
      def first
        first = @message.ffi_delegate.first
        return nil if first.null?
        Frame.from_ffi_delegate(first)
      end

      # @return [Frame] last {Frame} of {Message}
      # @return [nil] if there are no frames
      def last
        last = @message.ffi_delegate.last
        return nil if last.null?
        Frame.from_ffi_delegate(last)
      end

      # @overload [](index)
      #   @param index [Integer] index of {Frame} within {Message}
      # @overload [](*args)
      #   @note See Array#[] for details.
      # @return [Frame] frame Message
      # @return [nil] if there are no corresponding frames
      def [](*args)
        case args
        when [0] then first # speed up
        when [-1] then last # speed up
        else to_a[*args]
        end
      end

      # @note Not thread safe.
      # @return [self]
      def each
        first = first()
        return unless first
        yield first
        while _next = @message.ffi_delegate.next and not _next.null?
          yield Frame.from_ffi_delegate(_next)
        end
        return self
      end
    end
  end
end
