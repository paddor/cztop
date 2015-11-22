module CZTop
   # just because Proxy and Authenticator are actors
  class Actor

    # @param str_or_msg [String, Message]
    def send(str_or_msg)
      str_or_msg = Message.coerce(str_or_msg)
      @delegate.send(str_or_msg)
    end

    # @return [Message]
    def receive
      zmsg = @delegate.recv
      return Message.from_ptr()
      # TODO: maybe just Message.from_socket(self) ?
    end
  end
end
