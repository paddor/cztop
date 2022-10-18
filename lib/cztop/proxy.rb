# frozen_string_literal: true

module CZTop
  # Steerable proxy which switches messages between a frontend and a backend
  # socket.
  #
  # This is implemented using an {Actor}.
  #
  # @see http://api.zeromq.org/czmq3-0:zproxy
  class Proxy

    include ::CZMQ::FFI

    # function pointer to the +zmonitor()+ function
    ZPROXY_FPTR = ::CZMQ::FFI.ffi_libraries.each do |dl|
      fptr = dl.find_function('zproxy')
      break fptr if fptr
    end
    raise LoadError, "couldn't find zproxy()" if ZPROXY_FPTR.nil?

    def initialize
      @actor = Actor.new(ZPROXY_FPTR)
    end

    # @return [Actor] the actor behind this proxy
    attr_reader :actor

    # Terminates the proxy.
    # @return [void]
    def terminate
      @actor.terminate
    end


    # Enable verbose logging of commands and activity.
    # @return [void]
    def verbose!
      @actor << 'VERBOSE'
      @actor.wait
    end


    # Returns a configurator object which you can use to configure the
    # frontend socket.
    # @return [Configurator] (memoized) frontend configurator
    def frontend
      @frontend ||= Configurator.new(self, :frontend)
    end


    # Returns a configurator object which you can use to configure the backend
    # socket.
    # @return [Configurator] (memoized) backend configurator
    def backend
      @backend ||= Configurator.new(self, :backend)
    end


    # Captures all proxied messages and delivers them to a PULL socket bound
    # to the specified endpoint.
    # @note The PULL socket has to be bound before calling this method.
    # @param endpoint [String] the endpoint to which the PULL socket is bound to
    # @return [void]
    def capture(endpoint)
      @actor << ['CAPTURE', endpoint]
      @actor.wait
    end


    # Pauses proxying of any messages.
    # @note This causes any messages to be queued up and potentialy hit the
    #   high-water mark on the frontend or backend socket, causing messages to
    #   be dropped or writing applications to block.
    # @return [void]
    def pause
      @actor << 'PAUSE'
      @actor.wait
    end


    # Resume proxying of messages.
    # @note This is only needed after a call to {#pause}, not to start the
    #   proxy. Proxying starts as soon as the frontend and backend sockets are
    #   properly attached.
    # @return [void]
    def resume
      @actor << 'RESUME'
      @actor.wait
    end


    # Used to configure the socket on one side of a {Proxy}.
    class Configurator

      # @return [Array<Symbol>] supported socket types
      SOCKET_TYPES = %i[
        PAIR PUB SUB REQ REP
        DEALER ROUTER PULL PUSH
        XPUB XSUB
      ].freeze

      # @param proxy [Proxy] the proxy instance
      # @param side [Symbol] :frontend or :backend
      def initialize(proxy, side)
        @proxy = proxy
        @side  = case side
                 when :frontend then 'FRONTEND'
                 when :backend then 'BACKEND'
                 else raise ArgumentError, "invalid side: #{side.inspect}"
                 end
      end

      # @return [Proxy] the proxy this {Configurator} works on
      attr_reader :proxy

      # @return [String] the side, either "FRONTEND" or "BACKEND"
      attr_reader :side

      # Creates and binds a serverish socket.
      # @param socket_type [Symbol] one of {SOCKET_TYPES}
      # @param endpoint [String] endpoint to bind to
      # @raise [ArgumentError] if the given socket type is invalid
      # @return [void]
      def bind(socket_type, endpoint)
        raise ArgumentError, "invalid socket type: #{socket_type}" unless SOCKET_TYPES.include?(socket_type)

        @proxy.actor << [@side, socket_type.to_s, endpoint]
        @proxy.actor.wait
      end


      # Set ZAP domain for authentication.
      # @param domain [String] the ZAP domain
      def domain=(domain)
        @proxy.actor << ['DOMAIN', @side, domain]
        @proxy.actor.wait
      end


      # Configure PLAIN authentication on this socket.
      # @note You'll have to use a {CZTop::Authenticator}.
      def PLAIN_server!
        @proxy.actor << ['PLAIN', @side]
        @proxy.actor.wait
      end


      # Configure CURVE authentication on this socket.
      # @note You'll have to use a {CZTop::Authenticator}.
      # @param cert [Certificate] this server's certificate,
      #   so remote clients are able to authenticate this server
      def CURVE_server!(cert)
        public_key = cert.public_key
        secret_key = cert.secret_key or
          raise ArgumentError, 'no secret key in certificate'

        @proxy.actor << ['CURVE', @side, public_key, secret_key]
        @proxy.actor.wait
      end

    end

  end
end
