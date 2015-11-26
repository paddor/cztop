module CZTop
  # TODO
  class Message
    include FFIDelegate

    # TODO
    def self.from_socket(socket)
      from_ffi_delegate(CZMQ::FFI::Zmsg.recv(socket))
    end

    # TODO
    # @param msg [Message, String, Frame]
    def self.coerce(msg)
      case msg
      when Message
        return msg
      when String, Frame
        return new(msg)
      else
        raise "cannot coerce message: %p" % msg
      end
    end

    # TODO
    # @param content [String, Frame]
    def initialize(content=nil)
      attach_ffi_delegate(CZMQ::FFI::Zmsg.new)
      self << content if content
    end

    # TODO
    def empty?
      content_size.zero?
    end

    # Send {Message} to a {Socket}/{Actor}.
    # @note Do not use this {Message} anymore afterwards. Its native
    #   counterpart will have been destroyed.
    def send_to(destination)
      CZMQ::FFI::Zmsg.send(ffi_delegate, destination)
    end

    # Receive {Message} from a {Socket} or {Actor}.
    def self.receive_from(source)
      from_ffi_delegate(CZMQ::FFI::Zmsg.recv(source))
    end

    # TODO
    def <<(str_or_frame)
      case str_or_frame
      when String
        ffi_delegate.addstr(str_or_frame)
      when Frame
        ffi_delegate.append(str_or_frame.to_ptr)
      end
    end

    # TODO
    # @return [Integer] number of frames
    def size
      frames.count
    end

    # TODO
    # @return [Integer] number of bytes? FIXME in total
    def content_size
      ffi_delegate.content_size
    end

    # TODO
    def []
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
