# frozen_string_literal: true

module CZTop
  class Socket

    # Stream socket for the native pattern. This is useful when
    # communicating with a non-ZMQ peer over TCP.
    # @see http://api.zeromq.org/4-2:zmq-socket#toc16
    class STREAM < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        super

        attach_ffi_delegate(Zsock.new_stream(endpoints))
      end

    end

  end
end
