# frozen_string_literal: true

module CZTop
  class Socket

    # Extended subscribe socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    #
    class XSUB < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to connect to
      # @param curve [Hash, nil] CURVE encryption options
      #
      def initialize(endpoints = nil, curve: nil)
        super

        attach_ffi_delegate(Zsock.new(Types::XSUB))
        _apply_curve(curve)
        _attach(endpoints, default: :connect)
      end

    end

  end
end
