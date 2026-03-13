# frozen_string_literal: true

module CZTop
  class Socket

    # Stream socket for the native pattern. This is useful when
    # communicating with a non-ZMQ peer over TCP.
    # @see http://api.zeromq.org/4-2:zmq-socket#toc16
    #
    class STREAM < Socket

      include Readable
      include Writable

      # @param endpoints [String] endpoints to connect to
      # @param curve [Hash, nil] CURVE encryption options
      #
      def initialize(endpoints = nil, curve: nil)
        super

        attach_ffi_delegate(Zsock.new(Types::STREAM))
        _apply_curve(curve)
        _attach(endpoints, default: :connect)
      end

    end

  end
end
