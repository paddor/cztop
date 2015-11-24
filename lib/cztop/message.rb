module CZTop
  class Message
    include NativeDelegate

    def self.from_socket(socket)
      from_delegate(CZMQ::FFI::Zmsg.recv(socket))
    end

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

    # @param content [String, Frame]
    def initialize(content=nil)
      self.delegate = CZMQ::FFI::Zmsg.new
      self << content if content
    end

    def empty?
      content_size.zero?
    end

    def send_to(destination)
      CZMQ::FFI::Zmsg.send(@delegate, destination)
    end

    def self.receive_from(source)
      from_delegate(CZMQ::FFI::Zmsg.recv(source))
    end

    def <<(str_or_frame)
      case str_or_frame
      when String
        @delegate.addstr(str_or_frame)
      when Frame
        @delegate.append(str_or_frame.to_ptr)
      end
    end

    # @return [Integer] number of frames
    def size
      frames.count
    end

    # @return [Integer] number of bytes? FIXME in total
    def content_size
      @delegate.content_size
    end

    def []
    end

    def frames
      Frames.new(self)
    end

    class Frames
      include Enumerable

      # @param message [Message]
      def initialize(message)
        @message = message
      end

      def first
        first = @message.delegate.first
        return nil if first.null?
        Frame.from_delegate(first)
      end

      def last
        last = @message.delegate.last
        return nil if last.null?
        Frame.from_delegate(last)
      end

      def [](*args)
        case args
        when [0] then first
        when [-1] then last
        else to_a[*args]
        end
      end

      # @note Not thread safe.
      def each
        first = first()
        return unless first
        yield first
        while _next = @message.delegate.next and not _next.null?
          yield Frame.from_delegate(_next)
        end
        return self
      end
    end
  end
end
