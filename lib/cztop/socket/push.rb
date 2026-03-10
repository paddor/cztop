# frozen_string_literal: true

module CZTop
  class Socket

    # Push socket for the ZeroMQ Pipeline Pattern.
    # @see http://rfc.zeromq.org/spec:30
    class PUSH < Socket

      include Writable

      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        super

        attach_ffi_delegate(Zsock.new_push(endpoints))
      end

    end

  end
end
