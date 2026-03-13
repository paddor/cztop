# frozen_string_literal: true

module CZTop
  class Socket

    # Dealer socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    #
    class DEALER < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to connect to
      # @param curve [Hash, nil] CURVE encryption options
      #
      def initialize(endpoints = nil, curve: nil)
        super

        attach_ffi_delegate(Zsock.new(Types::DEALER))
        _apply_curve(curve)
        _attach(endpoints, default: :connect)
      end

    end

  end
end
