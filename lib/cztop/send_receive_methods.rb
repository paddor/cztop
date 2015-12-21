module CZTop

  # These are methods that can be used on a {Socket} as well as an {Actor},
  # but actually just pass through to methods of {Message} (which take
  # a polymorphic reference, in Ruby as well as in C).
  # @see http://api.zeromq.org/czmq3-0:zmsg
  module SendReceiveMethods
    # Sends a message.
    # @param str_or_msg [Message, String] what to send
    def send(str_or_msg)
      Message.coerce(str_or_msg).send_to(self)
    end
    alias_method :<<, :send

    # Receives a message.
    # @return [Message]
    def receive
      Message.receive_from(self)
    end
  end
end
