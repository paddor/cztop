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
      #
      def initialize(endpoints = nil)
        super

        attach_ffi_delegate(Zsock.new_xpub(endpoints))
      end

    end

  end
end
