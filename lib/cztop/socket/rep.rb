# frozen_string_literal: true

module CZTop
  class Socket

    # Reply socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    #
    class REP < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to bind to
      #
      def initialize(endpoints = nil)
        super

        attach_ffi_delegate(Zsock.new_rep(endpoints))
      end

    end

  end
end
