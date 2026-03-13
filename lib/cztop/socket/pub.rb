# frozen_string_literal: true

module CZTop
  class Socket

    # Publish socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    #
    class PUB < Socket

      include Writable

      # @param endpoints [String] endpoints to bind to
      # @param curve [Hash, nil] CURVE encryption options
      #
      def initialize(endpoints = nil, curve: nil)
        super

        attach_ffi_delegate(Zsock.new(Types::PUB))
        _apply_curve(curve)
        _attach(endpoints, default: :bind)
      end

    end

  end
end
