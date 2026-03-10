# frozen_string_literal: true

module CZTop
  class Socket

    # Request socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    class REQ < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        super

        attach_ffi_delegate(Zsock.new_req(endpoints))
      end

    end

  end
end
