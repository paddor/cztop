# frozen_string_literal: true

module CZTop
  class Socket

    # Dealer socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    class DEALER < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        super

        attach_ffi_delegate(Zsock.new_dealer(endpoints))
      end

    end

  end
end
