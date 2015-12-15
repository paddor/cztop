module CZTop
  class Socket
    #  Socket types. Each constant in this namespace holds the type code used
    #  for the zsock_new() function.
    module Types
      PAIR = 0
      PUB = 1
      SUB = 2
      REQ = 3
      REP = 4
      DEALER = 5
      ROUTER = 6
      PULL = 7
      PUSH = 8
      XPUB = 9
      XSUB = 10
      STREAM = 11
      SERVER = 12
      CLIENT = 13
    end

    # All the available type codes, mapped to their Symbol equivalent.
    # @return [Hash<Integer, Symbol>]
    TypeNames = Hash[
      Types.constants.map { |name| i = Types.const_get(name); [ i, name ] }
    ].freeze

    # @param type [Symbol, Integer] type from {Types} or like +:PUB+
    # @return [REQ, REP, PUSH, PULL, ... ] the new socket
    # @see Types
    # @example Creating a socket by providing its type as a parameter
    #   my_sock = CZTop::Socket.new_by_type(:DEALER, "tcp://example.com:4000")
    def self.new_by_type(type)
      case type
      when Integer
        type_code = type
        type_name = TypeNames[type_code] or
          raise ArgumentError, "invalid type %p" % type
        type_class = Socket.const_get(type_name)
      when Symbol
        type_code = Types.const_get(type)
        type_class = Socket.const_get(type)
      else
        raise ArgumentError, "invalid socket type: %p" % type
      end
      ffi_delegate = CZMQ::FFI::Zsock.new(type_code)
      sock = type_class.allocate
      sock.attach_ffi_delegate(ffi_delegate)
      sock
    end

    # Client socket for the ZeroMQ Client-Server Pattern.
    # @see http://rfc.zeromq.org/spec:41
    class CLIENT < Socket
      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_client(endpoints))
      end
    end

    # Server socket for the ZeroMQ Client-Server Pattern.
    # @see http://rfc.zeromq.org/spec:41
    class SERVER < Socket
      # @param endpoints [String] endpoints to bind to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_server(endpoints))
      end

#      # Gets the routing ID.
#      # @note This only set when the frame came from a {CZTop::Socket::SERVER}
#      #   socket.
#      # @return [Integer] the routing ID, or 0 if unset
#      ffi_delegate :routing_id
#
#      # Sets a new routing ID.
#      # @note This is used when the frame is sent to a {CZTop::Socket::SERVER}
#      #   socket.
#      # @param new_routing_id [Integer] new routing ID
#      # @raise [RangeError] if new routing ID is out of +uint32_t+ range
#      # @return [new_routing_id]
#      def routing_id=(new_routing_id)
#        # need to raise manually, as FFI lacks this feature.
#        # @see https://github.com/ffi/ffi/issues/473
#        raise RangeError if new_routing_id < 0
#        ffi_delegate.set_routing_id(new_routing_id)
#      end
    end

    # Request socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    class REQ < Socket
      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_req(endpoints))
      end
    end

    # Reply socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    class REP < Socket
      # @param endpoints [String] endpoints to bind to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_rep(endpoints))
      end
    end

    # Dealer socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    class DEALER < Socket
      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_dealer(endpoints))
      end
    end

    # Router socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    class ROUTER < Socket
      # @param endpoints [String] endpoints to bind to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_router(endpoints))
      end
    end

    # Publish socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    class PUB < Socket
      # @param endpoints [String] endpoints to bind to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_pub(endpoints))
      end
    end

    # Subscribe socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    class SUB < Socket
      # @param endpoints [String] endpoints to connect to
      # @param subscription [String] what to subscribe to
      def initialize(endpoints = nil, subscription = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_sub(endpoints, subscription))
      end

      # Subscribes to the given prefix string.
      # @param prefix [String] prefix string to subscribe to
      # @return [void]
      def subscribe(prefix)
        ffi_delegate.set_subscribe(prefix)
      end

      # Unsubscribes from the given prefix.
      # @param prefix [String] prefix string to unsubscribe from
      # @return [void]
      def unsubscribe(prefix)
        ffi_delegate.set_unsubscribe(prefix)
      end
    end

    # Extended publish socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    class XPUB < Socket
      # @param endpoints [String] endpoints to bind to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_xpub(endpoints))
      end
    end

    # Extended subscribe socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    class XSUB < Socket
      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_xsub(endpoints))
      end
    end

    # Push socket for the ZeroMQ Pipeline Pattern.
    # @see http://rfc.zeromq.org/spec:30
    class PUSH < Socket
      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_push(endpoints))
      end
    end

    # Pull socket for the ZeroMQ Pipeline Pattern.
    # @see http://rfc.zeromq.org/spec:30
    class PULL < Socket
      # @param endpoints [String] endpoints to bind to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_pull(endpoints))
      end
    end

    # Pair socket for inter-thread communication.
    # @see http://rfc.zeromq.org/spec:31
    class PAIR < Socket
      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_pair(endpoints))
      end
    end

    # Stream socket for the native pattern over. This is useful when
    # communicating with a non-ZMQ peer, done over TCP.
    # @see http://api.zeromq.org/4-2:zmq-socket#toc16
    class STREAM < Socket
      # @param endpoints [String] endpoints to connect to
      def initialize(endpoints = nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_stream(endpoints))
      end
    end
  end
end
