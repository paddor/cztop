# frozen_string_literal: true

module CZTop
  class Socket

    # Subscribe socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    #
    class SUB < Socket

      include Readable

      # @param endpoints [String] endpoints to connect to
      # @param subscription [String] what to subscribe to
      #
      def initialize(endpoints = nil, subscription = nil)
        super(endpoints)

        attach_ffi_delegate(Zsock.new_sub(endpoints, subscription))
      end

      # @return [String] subscription prefix to subscribe to everything
      EVERYTHING = ''

      # Subscribes to the given prefix string.
      # @param prefix [String] prefix string to subscribe to
      # @return [void]
      #
      def subscribe(prefix = EVERYTHING)
        ffi_delegate.set_subscribe(prefix)
      end


      # Unsubscribes from the given prefix.
      # @param prefix [String] prefix string to unsubscribe from
      # @return [void]
      #
      def unsubscribe(prefix)
        ffi_delegate.set_unsubscribe(prefix)
      end

    end

  end
end
