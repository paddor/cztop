# frozen_string_literal: true

module CZTop
  class Socket

    # Router socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    #
    class ROUTER < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to bind to
      #
      def initialize(endpoints = nil)
        super

        attach_ffi_delegate(Zsock.new_router(endpoints))
      end


      # Send a message to a specific receiver. This is a shorthand for when
      # you send a message to a specific receiver with no hops in between.
      # @param receiver [String] receiving peer's socket identity
      # @param message [String, Array<String>] the message to send
      #
      def send_to(receiver, message)
        parts = message.is_a?(Array) ? message : [message]
        send([receiver, '', *parts])
      end
    end

  end
end
