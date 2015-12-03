module CZTop
  # Represents a {CZMQ::FFI::Zmsg}.
  class Message
    # @!parse extend CZTop::FFIDelegate::ClassMethods


    include FFIDelegate

    # Coerces an object into a {Message}.
    # @param msg [Message, String, Frame]
    # @return [Message]
    # @raise [ArgumentError] if it can't be coerced
    def self.coerce(msg)
      case msg
      when Message
        return msg
      when String, Frame
        return new(msg)
      else
        raise ArgumentError, "cannot coerce message: %p" % msg
      end
    end

    # @param content [String, Frame]
    def initialize(content=nil)
      attach_ffi_delegate(CZMQ::FFI::Zmsg.new)
      self << content if content
    end

    # @return [Boolean] if this message is empty or not
    def empty?
      content_size.zero?
    end

    # Send {Message} to a {Socket} or {Actor}.
    # @param destination [Socket, Actor]
    # @note Do not use this {Message} anymore afterwards. Its native
    #   counterpart will have been destroyed.
    def send_to(destination)
      CZMQ::FFI::Zmsg.send(ffi_delegate, destination)
    end

    # Receive a {Message} from a {Socket} or {Actor}.
    # @param source [Socket, Actor]
    # @return [Message]
    def self.receive_from(source)
      from_ffi_delegate(CZMQ::FFI::Zmsg.recv(source))
    end

    # Append something to this message.
    # @param obj [String, Frame]
    # @raise [ArgumentError] if obj has an invalid type
    def <<(obj)
      case obj
      when String
        ffi_delegate.addstr(obj)
      when Frame
        ffi_delegate.append(obj.to_ptr)
      else
        raise ArgumentError, "invalid object: %p" % obj
      end
    end

    # @return [Integer] number of frames
    # @see content_size
    def size
      frames.count
    end

    # @return [Integer] size of this message in bytes
    # @see size
    def content_size
      ffi_delegate.content_size
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
