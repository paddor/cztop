# frozen_string_literal: true

module CZTop
  class Socket

    # Push socket for the ZeroMQ Pipeline Pattern.
    # @see http://rfc.zeromq.org/spec:30
    #
    class PUSH < Socket

      include Writable

      # @param endpoints [String] endpoints to connect to
      # @param curve [Hash, nil] CURVE encryption options
      #
      def initialize(endpoints = nil, curve: nil)
        super

        attach_ffi_delegate(Zsock.new(Types::PUSH))
        _apply_curve(curve)
        _attach(endpoints, default: :connect)
      end

    end

  end
end
