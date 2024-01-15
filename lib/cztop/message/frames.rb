# frozen_string_literal: true

module CZTop
  class Message

    # @return [Integer] number of frames
    # @see content_size
    def size
      ffi_delegate.size
    end


    # Access to this {Message}'s {Frame}s.
    # @return [FramesAccessor]
    def frames
      FramesAccessor.new(self)
    end


    # Used to access a {Message}'s {Frame}s.
    class FramesAccessor

      include Enumerable

      # @param message [Message]
      def initialize(message)
        @message = message
      end


      # Returns the last frame of this message.
      # @return [Frame] first frame of Message
      # @return [nil] if there are no frames
      def first
        first = @message.ffi_delegate.first
        return nil if first.null?

        Frame.from_ffi_delegate(first)
      end


      # Returns the last frame of this message.
      # @return [Frame] last {Frame} of {Message}
      # @return [nil] if there are no frames
      def last
        last = @message.ffi_delegate.last
        return nil if last.null?

        Frame.from_ffi_delegate(last)
      end


      # Index access to a frame/frames of this message, just like with an
      # array.
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


      # Yields all frames for this message to the given block.
      # @note Not thread safe.
      # @yieldparam frame [Frame]
      # @return [self]
      def each
        first = first()
        return unless first

        yield first
        while (frame = @message.ffi_delegate.next) && !frame.null?
          yield Frame.from_ffi_delegate(frame)
        end
        self
      end

    end

  end
end
