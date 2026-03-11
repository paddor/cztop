# frozen_string_literal: true

module CZTop
  class Socket

    # Pair socket for inter-thread communication.
    # @see http://rfc.zeromq.org/spec:31
    #
    class PAIR < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to connect to
      #
      def initialize(endpoints = nil)
        super

        attach_ffi_delegate(Zsock.new_pair(endpoints))
      end

    end

  end
end
