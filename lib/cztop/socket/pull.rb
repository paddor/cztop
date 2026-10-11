# frozen_string_literal: true

module CZTop
  class Socket

    # Pull socket for the ZeroMQ Pipeline Pattern.
    # @see http://rfc.zeromq.org/spec:30
    #
    class PULL < Socket

      include Readable

      # @param endpoints [String] endpoints to bind to
      # @param curve [Hash, nil] CURVE encryption options
      # @param linger [Numeric, nil] linger period in seconds (default: 0)
      #
      def initialize(endpoints = nil, curve: nil, linger: 0)
        super

        attach_ffi_delegate(Zsock.new(Types::PULL))
        self.linger = linger
        _apply_curve(curve)
        _attach(endpoints, default: :bind)
      end

    end

  end
end
