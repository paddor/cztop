module CZTop
  # Represents a {CZMQ::FFI::Zsock}.
  class Socket
    include FFIDelegate

    #  Socket types
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

    TypeNames = Hash[
      Types.constants.map do |name| 
        code = Types.const_get(name)
        [ code, name ]
      end
    ].freeze

    # @param type [Symbol, Integer] type from {Types} or like +:PUB+
    # @return [REQ, REP, PUSH, PULL, ..., Socket] the new socket
    # @see Types
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

    # @return [String] last bound endpoint, if any
    def last_endpoint
      ffi_delegate.endpoint
    end

    # Sends a signal.
    # @param [Integer] signal (0-255)
    ffi_delegate :signal
    
    # Waits for a signal.
    # @return [Integer] the received signal
    ffi_delegate :wait

    # Sends a message.
    # @param str_or_msg [Message, String] what to send
    def send(str_or_msg)
      Message.coerce(str_or_msg).send_to(self)
    end
    alias_method :<<, :send

    # Receives a message.
    # @return [Message]
    def receive
      Message.receive_from(self)
    end

    # Connects to an endpoint.
    # @param endpoint [String]
    def connect(endpoint)
      ffi_delegate.connect(endpoint)
    end

    # Disconnects from an endpoint.
    # @param endpoint [String]
    def disconnect(endpoint)
      # we can do sprintf in Ruby
      ffi_delegate.disconnect(endpoint, *nil)
    end

    # Binds to an endpoint.
    # @param endpoint [String]
    def bind(endpoint)
      ffi_delegate.bind(endpoint)
    end

    # Unbinds from an endpoint.
    # @param endpoint [String]
    def unbind(endpoint)
      # we can do sprintf in Ruby
      ffi_delegate.unbind(endpoint, *nil)
    end

    # Access to the options of this socket.
    # @return [Options]
    def options
      Options.new(self)
    end

    # Sets an option by its name.
    # @param option [Symbol, String] option name like +:rcvhwm+
    # @param value [Integer, String] value, depending on the option
    def set_option(option, value)
      options.__send__(:"#{option}=", value)
    end

    # Gets an option by its name.
    # @param option [Symbol, String] option name like +:rcvhwm+
    # @return [Integer, String] value, depending on the option
    def get_option(option)
      options.__send__(option.to_sym, value)
    end

    # Used to access the options of a {Socket} or {Actor}.
    class Options
      # @param zocket [Socket, Actor]
      def initialize(zocket)
        @zocket = zocket
      end

      # TODO
    end

    # Client socket for the ZeroMQ Client-Server Pattern.
    # @see http://rfc.zeromq.org/spec:41
    class CLIENT < Socket
      # @param endpoints [String] endpoints
      def initialize(endpoints)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_client(endpoints))
      end
    end

    # Server socket for the ZeroMQ Client-Server Pattern.
    # @see http://rfc.zeromq.org/spec:41
    class SERVER < Socket
      # @param endpoints [String] endpoints
      def initialize(endpoints)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_server(endpoints))
      end
    end

    # Request socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    class REQ < Socket
      # @param endpoints [String] endpoints
      def initialize(endpoints)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_req(endpoints))
      end
    end

    # Reply socket for the ZeroMQ Request-Reply Pattern.
    # @see http://rfc.zeromq.org/spec:28
    class REP < Socket
      # @param endpoints [String] endpoints
      def initialize(endpoints)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_rep(endpoints))
      end
    end

    # Publish socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    class PUB < Socket
      # @param endpoints [String] endpoints
      def initialize(endpoints)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_pub(endpoints))
      end
    end

    # Subscribe socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    class SUB < Socket
      # @param endpoints [String] endpoints
      # @param subscription [String] what to subscribe to
      def initialize(endpoints, subscription=nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_sub(endpoints))
      end
    end

    # Extended publish socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    class XPUB < Socket
      # @param endpoints [String] endpoints
      def initialize(endpoints)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_xpub(endpoints))
      end
    end

    # Extended subscribe socket for the ZeroMQ Publish-Subscribe Pattern.
    # @see http://rfc.zeromq.org/spec:29
    class XSUB < Socket
      # @param endpoints [String] endpoints
      def initialize(endpoints)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_xsub(endpoints))
      end
    end

    # Push socket for the ZeroMQ Pipeline Pattern.
    # @see http://rfc.zeromq.org/spec:30
    class PUSH < Socket
      # @param endpoints [String] endpoints
      def initialize(endpoints)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_push(endpoints))
      end
    end

    # Pull socket for the ZeroMQ Pipeline Pattern.
    # @see http://rfc.zeromq.org/spec:30
    class PULL < Socket
      # @param endpoints [String] endpoints
      def initialize(endpoints)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_pull(endpoints))
      end
    end

    # Pair socket for inter-thread communication.
    # @see http://rfc.zeromq.org/spec:31
    class PAIR < Socket
      # @param endpoints [String] endpoints
      def initialize(endpoints)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_pair(endpoints))
      end
    end

    # Stream socket for the native pattern over. This is useful when
    # communicating with a non-ZMQ peer, done over TCP.
    # @see http://api.zeromq.org/4-2:zmq-socket#toc16
    class STREAM < Socket
      # @param endpoints [String] endpoints
      def initialize(endpoints)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_stream(endpoints))
      end
    end
  end
end
