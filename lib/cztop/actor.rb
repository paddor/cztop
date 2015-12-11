module CZTop
  # @note Mainly because Proxy and Authenticator are actors.
  class Actor
    # @!parse extend CZTop::HasFFIDelegate::ClassMethods


    include HasFFIDelegate
    include ZsockOptions

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
      # TODO: maybe just Message.receive_from(self) ?
      #
      # Is there any difference??
    end
  end
end
