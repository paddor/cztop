# frozen_string_literal: true

module CZTop
  class Socket

    # Extended publish socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    #
    class XPUB < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to bind to
      # @param curve [Hash, nil] CURVE encryption options
      # @param linger [Integer] linger period in milliseconds (default: 0)
      #
      def initialize(endpoints = nil, curve: nil, linger: 0)
        super

        attach_ffi_delegate(Zsock.new(Types::XPUB))
        self.linger = linger
        _apply_curve(curve)
        _attach(endpoints, default: :bind)
      end

    end

  end
end
