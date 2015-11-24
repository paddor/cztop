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
        Frame.from_delegate(@message.delegate.first)
      end

      def last
        Frame.from_delegate(@message.delegate.last)
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
        while _next = self.next
          yield _next
        end
      end
    end
  end
end
