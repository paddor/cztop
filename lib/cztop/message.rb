module CZTop
  class Message
    include NativeDelegate

    def self.from_socket(socket)
      ptr = CZMQ::FFI::Zmsg.recv(socket.to_ptr)
      delegate = CZMQ::FFI::Zmsg.__new(ptr)
      msg = new()
      msg.delegate = delegate
      return msg
    end

    def initialize
    end

    def send_to(socket)
      CZMQ::FFI::Zmsg.send(@delegate.__ptr_give_ref, socket.to_ptr)
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
    end
  end
end
