# frozen_string_literal: true

module CZTop
  class Socket

    # Pull socket for the ZeroMQ Pipeline Pattern.
    # @see http://rfc.zeromq.org/spec:30
    #
    class PULL < Socket

      include Readable

      # @param endpoints [String] endpoints to bind to
      #
      def initialize(endpoints = nil)
        super

        attach_ffi_delegate(Zsock.new_pull(endpoints))
      end

    end

  end
end
