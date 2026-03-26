# frozen_string_literal: true

module CZTop
  class Socket

    # Subscribe socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    #
    class SUB < Socket

      include Readable

      # @return [String] subscription prefix to subscribe to everything
      EVERYTHING = ''

      # @param endpoints [String] endpoints to connect to
      # @param prefix [String, nil] subscription prefix; defaults to no
      #   subscription. Pass {EVERYTHING} (+""+) to subscribe to everything.
      # @param curve [Hash, nil] CURVE encryption options
      # @param linger [Integer] linger period in milliseconds (default: 0)
      #
      def initialize(endpoints = nil, prefix: nil, curve: nil, linger: 0)
        super(endpoints, curve: curve, linger: linger)

        attach_ffi_delegate(Zsock.new(Types::SUB))
        self.linger = linger
        _apply_curve(curve)
        subscribe(prefix) unless prefix.nil?
        _attach(endpoints, default: :connect)
      end

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
