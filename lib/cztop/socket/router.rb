# frozen_string_literal: true

module CZTop
  class Socket

    # Router socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    class ROUTER < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to bind to
      def initialize(endpoints = nil)
        super

        attach_ffi_delegate(Zsock.new_router(endpoints))
      end


      # Send a message to a specific receiver. This is a shorthand for when
      # you send a message to a specific receiver with no hops in between.
      # @param receiver [String] receiving peer's socket identity
      # @param message [Message] the message to send
      # @note Do NOT use the message afterwards. It'll have been modified and
      #   destroyed.
      def send_to(receiver, message)
        message = Message.coerce(message)
        message.prepend ''       # separator frame
        message.prepend receiver # receiver envelope
        self << message
      end
    end

  end
end
