module CZTop
  # @note Mainly because Proxy and Authenticator are actors.
  class Actor
    include FFIDelegate

    def initialize
      # TODO
    end

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

    # Access to the options of this actor.
    # @return [Socket::Options]
    def options
      Socket::Options.new(self)
    end
  end
end
