# frozen_string_literal: true

module CZTop
  class Socket

    # Pair socket for inter-thread communication.
    # @see http://rfc.zeromq.org/spec:31
    #
    class PAIR < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to connect to
      # @param curve [Hash, nil] CURVE encryption options
      # @param linger [Integer] linger period in milliseconds (default: 0)
      #
      def initialize(endpoints = nil, curve: nil, linger: 0)
        super

        attach_ffi_delegate(Zsock.new(Types::PAIR))
        self.linger = linger
        _apply_curve(curve)
        _attach(endpoints, default: :connect)
      end

    end

  end
end
