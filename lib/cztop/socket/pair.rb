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
      #
      def initialize(endpoints = nil, curve: nil)
        super

        attach_ffi_delegate(Zsock.new(Types::PAIR))
        _apply_curve(curve)
        _attach(endpoints, default: :connect)
      end

    end

  end
end
