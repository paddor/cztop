# frozen_string_literal: true

module CZTop
  # These are methods that can be used on a {Socket} as well as an {Actor},
  # but actually just pass through to methods of {Message} (which take
  # a polymorphic reference, in Ruby as well as in C).
  # @see http://api.zeromq.org/czmq3-0:zmsg
  module SendReceiveMethods

    # Sends a message.
    #
    # @param message [Message, String, Array<parts>] the message to send
    # @raise [IO::EAGAINWaitWritable] if send timeout has been reached (see
    #   {ZsockOptions::OptionsAccessor#sndtimeo=})
    # @raise [Interrupt, ArgumentError, SystemCallError] anything raised by
    #   {Message#send_to}
    # @return [self]
    # @see Message.coerce
    # @see Message#send_to
    def <<(message)
      Message.coerce(message).send_to(self)
      self
    end


    # Receives a message.
    #
    # @return [Message]
    # @raise [IO::EAGAINWaitReadable] if receive timeout has been reached (see
    #   {ZsockOptions::OptionsAccessor#rcvtimeo=})
    # @raise [Interrupt, ArgumentError, SystemCallError] anything raised by
    #   {Message.receive_from}
    # @see Message.receive_from
    def receive
      Message.receive_from(self)
    end

  end
end
