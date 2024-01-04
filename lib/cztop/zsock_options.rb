# frozen_string_literal: true

module CZTop
  # This module adds the ability to access options of a {Socket} or an
  # {Actor}.
  #
  # @note Most socket options only take effect for subsequent bind/connects.
  #
  # @see http://api.zeromq.org/4-1:zmq-setsockopt
  # @see http://api.zeromq.org/4-1:zmq-getsockopt
  # @see http://api.zeromq.org/czmq3-0:zsock-option
  #
  module ZsockOptions

    # Access to the options of this socket.
    # @return [OptionsAccessor] the memoized options accessor
    def options
      @options ||= OptionsAccessor.new(self)
    end


    # Checks whether there's a message that can be read from the socket
    # without blocking.
    # @return [Boolean] whether the socket is readable
    def readable?
      (options.events & Poller::ZMQ::POLLIN).positive?
    end


    # Checks whether at least one message can be written to the socket without
    # blocking.
    # @return [Boolean] whether the socket is writable
    def writable?
      (options.events & Poller::ZMQ::POLLOUT).positive?
    end


    # Useful for registration in an event-loop.
    # @return [Integer]
    # @see OptionsAccessor#fd
    def fd
      options.fd
    end


    # Used to access the options of a {Socket} or {Actor}.
    class OptionsAccessor

      # @return [Socket, Actor] whose options this {OptionsAccessor} instance
      #   is accessing
      attr_reader :zocket

      # @param zocket [Socket, Actor]
      def initialize(zocket)
        @zocket = zocket
      end


      # Fuzzy option getter. This is to make it easier when porting
      # applications from CZMQ libraries to CZTop.
      # @param option_name [Symbol, String] case insensitive option name
      # @raise [NoMethodError] if option name can't be recognized
      def [](option_name)
        # NOTE: beware of predicates, especially #CURVE_server? & friends
        meth = public_methods.grep_v(/=$/)
                             .find { |m| m =~ /^#{option_name}\??$/i }
        raise NoMethodError, option_name if meth.nil?

        __send__(meth)
      end


      # Fuzzy option setter. This is to make it easier when porting
      # applications from CZMQ libraries to CZTop.
      # @param option_name [Symbol, String] case insensitive option name
      # @param new_value [String, Integer] new value
      # @raise [NoMethodError] if option name can't be recognized
      def []=(option_name, new_value)
        meth = public_methods.find { |m| m =~ /^#{option_name}=$/i }
        raise NoMethodError, option_name if meth.nil?

        __send__(meth, new_value)
      end

      include CZMQ::FFI

      # @!group High Water Marks

      # @return [Integer] the send high water mark
      def sndhwm
        Zsock.sndhwm(@zocket)
      end


      # @param value [Integer] the new send high water mark.
      def sndhwm=(value)
        Zsock.set_sndhwm(@zocket, value)
      end


      # @return [Integer] the receive high water mark
      def rcvhwm
        Zsock.rcvhwm(@zocket)
      end


      # @param value [Integer] the new receive high water mark
      def rcvhwm=(value)
        Zsock.set_rcvhwm(@zocket, value)
      end

      # @!endgroup

      # @!group Security Mechanisms

      # @return [Boolean] whether this zocket is a CURVE server
      def CURVE_server?
        Zsock.curve_server(@zocket).positive?
      end


      # Make this zocket a CURVE server.
      # @param bool [Boolean]
      # @note You'll have to use a {CZTop::Authenticator}.
      def CURVE_server=(bool)
        Zsock.set_curve_server(@zocket, bool ? 1 : 0)
      end


      # @return [String] Z85 encoded server key set
      # @return [nil] if the current mechanism isn't CURVE or CURVE isn't
      #   supported
      def CURVE_serverkey
        CURVE_key(:curve_serverkey)
      end


      # Get one of the CURVE keys.
      # @param key_name [Symbol] something like +:curve_serverkey+
      # @return [String, nil] key, if CURVE is supported and active, or nil
      def CURVE_key(key_name)
        return nil if mechanism != :CURVE

        ptr = Zsock.__send__(key_name, @zocket)
        return nil if ptr.null?

        ptr.read_string
      end
      private :CURVE_key

      # Sets the server's public key, so the zocket can authenticate the
      # remote server.
      # @param key [String] Z85 (40 bytes) or binary (32 bytes) server key
      # @raise [ArgumentError] if key has wrong size
      def CURVE_serverkey=(key)
        case key.bytesize
        when 40
          Zsock.set_curve_serverkey(@zocket, key)
        when 32
          ptr = ::FFI::MemoryPointer.from_string(key)
          Zsock.set_curve_serverkey_bin(@zocket, ptr)
        else
          raise ArgumentError, format('invalid server key: %p', key)
        end
      end

      # supported security mechanisms and their macro value equivalent
      MECHANISMS = {
        0 => :NULL,  # ZMQ_NULL
        1 => :PLAIN, # ZMQ_PLAIN
        2 => :CURVE, # ZMQ_CURVE
        3 => :GSSAPI # ZMQ_GSSAPI
      }.freeze

      # @return [Symbol] the current security mechanism in use
      # @note This is automatically set through the use of CURVE certificates,
      #   etc
      def mechanism
        # int zsock_mechanism (void *self);
        code = Zsock.mechanism(@zocket)
        MECHANISMS[code] or
          raise format('unknown ZMQ security mechanism code: %i', code)
      end


      # @return [String] Z85 encoded secret key set
      # @return [nil] if the current mechanism isn't CURVE or CURVE isn't
      #   supported
      def CURVE_secretkey
        CURVE_key(:curve_secretkey)
      end


      # @return [String] Z85 encoded public key set
      # @return [nil] if the current mechanism isn't CURVE or CURVE isn't
      #   supported
      def CURVE_publickey
        CURVE_key(:curve_publickey)
      end


      # Gets the ZAP domain used for authentication.
      # @see http://rfc.zeromq.org/spec:27
      # @return [String]
      def zap_domain
        Zsock.zap_domain(@zocket).read_string
      end


      # Sets the ZAP domain used for authentication.
      # @param domain [String] the new ZAP domain
      def zap_domain=(domain)
        raise ArgumentError, 'domain too long' if domain.bytesize > 254

        Zsock.set_zap_domain(@zocket, domain)
      end


      # @return [Boolean] whether this zocket is a PLAIN server
      def PLAIN_server?
        Zsock.plain_server(@zocket).positive?
      end


      # Make this zocket a PLAIN server.
      # @param bool [Boolean]
      # @note You'll have to use a {CZTop::Authenticator}.
      def PLAIN_server=(bool)
        Zsock.set_plain_server(@zocket, bool ? 1 : 0)
      end


      # @return [String] username set for PLAIN mechanism
      # @return [nil] if the current mechanism isn't PLAIN
      def PLAIN_username
        return nil if mechanism != :PLAIN

        Zsock.plain_username(@zocket).read_string
      end


      # @param username [String] username for PLAIN mechanism
      # @note You'll have to use a {CZTop::Authenticator}.
      def PLAIN_username=(username)
        Zsock.set_plain_username(@zocket, username)
      end


      # @return [String] password set for PLAIN mechanism
      # @return [nil] if the current mechanism isn't PLAIN
      def PLAIN_password
        return nil if mechanism != :PLAIN

        Zsock.plain_password(@zocket).read_string
      end


      # @param password [String] password for PLAIN mechanism
      def PLAIN_password=(password)
        Zsock.set_plain_password(@zocket, password)
      end

      # @!endgroup

      # @!group Send and Receive Timeouts

      # @return [Integer] the timeout in milliseconds when receiving a message
      # @see Message.receive_from
      # @note -1 means infinite, 0 means nonblocking
      def rcvtimeo
        Zsock.rcvtimeo(@zocket)
      end


      # @param timeout [Integer] new timeout in milliseconds
      # @see Message.receive_from
      # @note -1 means infinite, 0 means nonblocking
      def rcvtimeo=(timeout)
        Zsock.set_rcvtimeo(@zocket, timeout)
      end


      # @return [Integer] the timeout in milliseconds when sending a message
      # @see Message#send_to
      # @note -1 means infinite, 0 means nonblocking
      def sndtimeo
        Zsock.sndtimeo(@zocket)
      end


      # @param timeout [Integer] new timeout in milliseconds
      # @see Message#send_to
      # @note -1 means infinite, 0 means nonblocking
      def sndtimeo=(timeout)
        Zsock.set_sndtimeo(@zocket, timeout)
      end

      # @!endgroup

      # Accept only routable messages on ROUTER sockets. Default is off.
      # @param bool [Boolean] whether to error if a message isn't routable
      #   (either if the that peer isn't connected or its SNDHWM is reached)
      def router_mandatory=(bool)
        Zsock.set_router_mandatory(@zocket, bool ? 1 : 0)
      end


      # @return [String] current socket identity
      def identity
        Zsock.identity(@zocket).read_string
      end


      # @param identity [String] new socket identity
      # @raise [ArgumentError] if identity is invalid
      def identity=(identity)
        raise ArgumentError, 'zero-length identity' if identity.bytesize.zero?
        raise ArgumentError, 'identity too long' if identity.bytesize > 255
        raise ArgumentError, 'invalid identity' if identity.start_with? "\0"

        Zsock.set_identity(@zocket, identity)
      end


      # @return [Integer] current value of Type of Service
      def tos
        Zsock.tos(@zocket)
      end


      # @param new_value [Integer] new value for Type of Service
      def tos=(new_value)
        raise ArgumentError, 'invalid TOS' unless new_value >= 0

        Zsock.set_tos(@zocket, new_value)
      end


      # @return [Integer] current value of Heartbeat IVL
      def heartbeat_ivl
        Zsock.heartbeat_ivl(@zocket)
      end


      # @param new_value [Integer] new value for Heartbeat IVL
      def heartbeat_ivl=(new_value)
        raise ArgumentError, 'invalid IVL' unless new_value >= 0

        Zsock.set_heartbeat_ivl(@zocket, new_value)
      end


      # @return [Integer] current value of Heartbeat TTL, in milliseconds
      def heartbeat_ttl
        Zsock.heartbeat_ttl(@zocket)
      end


      # @param new_value [Integer] new value for Heartbeat TTL, in
      #   milliseconds
      # @note The value will internally be rounded to the nearest decisecond.
      #   So a value of less than 100 will have no effect.
      def heartbeat_ttl=(new_value)
        raise ArgumentError, "invalid TTL: #{new_value}" unless new_value.is_a? Integer
        raise ArgumentError, "TTL out of range: #{new_value}" unless (0..65_536).include? new_value

        Zsock.set_heartbeat_ttl(@zocket, new_value)
      end


      # @return [Integer] current value of Heartbeat Timeout
      def heartbeat_timeout
        Zsock.heartbeat_timeout(@zocket)
      end


      # @param new_value [Integer] new value for Heartbeat Timeout
      def heartbeat_timeout=(new_value)
        raise ArgumentError, 'invalid timeout' unless new_value >= 0

        Zsock.set_heartbeat_timeout(@zocket, new_value)
      end


      # @return [Integer] current value of LINGER
      def linger
        Zsock.linger(@zocket)
      end


      # This defines the number of milliseconds to wait while
      # closing/disconnecting a socket if there are outstanding messages to
      # send.
      #
      # Default is 0, which means to not wait at all. -1 means to wait
      # indefinitely
      #
      # @param new_value [Integer] new value for LINGER
      def linger=(new_value)
        Zsock.set_linger(@zocket, new_value)
      end


      # @return [Boolean] current value of ipv6
      def ipv6?
        Zsock.ipv6(@zocket) != 0
      end


      # Set the IPv6 option for the socket. A value of true means IPv6 is
      # enabled on the socket, while false means the socket will use only
      # IPv4.  When IPv6 is enabled the socket will connect to, or accept
      # connections from, both IPv4 and IPv6 hosts.
      # Default is false.
      # @param new_value [Boolean] new value for ipv6
      def ipv6=(new_value)
        Zsock.set_ipv6(@zocket, new_value ? 1 : 0)
      end


      # @return [Integer] socket file descriptor
      def fd
        Zsock.fd(@zocket)
      end


      # @return [Integer] socket events (readable/writable)
      # @see CZTop::Poller::ZMQ::POLLIN and CZTop::Poller::ZMQ::POLLOUT
      def events
        Zsock.events(@zocket)
      end


      # @return [Integer] current value of RECONNECT_IVL
      def reconnect_ivl
        Zsock.reconnect_ivl(@zocket)
      end


      # This defines the number of milliseconds to wait while
      # closing/disconnecting a socket if there are outstanding messages to
      # send.
      #
      # Default is 0, which means to not wait at all. -1 means to wait
      # indefinitely
      #
      # @param new_value [Integer] new value for RECONNECT_IVL
      def reconnect_ivl=(new_value)
        Zsock.set_reconnect_ivl(@zocket, new_value)
      end

    end

  end
end
