# frozen_string_literal: true

module CZTop
  class Socket

    # Extended subscribe socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    class XSUB < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        super

        attach_ffi_delegate(Zsock.new_xsub(endpoints))
      end

    end

  end
end
