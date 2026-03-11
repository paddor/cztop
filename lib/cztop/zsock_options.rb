# frozen_string_literal: true

module CZTop
  # This module adds the ability to access options of a {Socket}.
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


    # @api private
    POLLIN  = 1
    POLLOUT = 2

    # Checks whether there's a message that can be read from the socket
    # without blocking.
    # @return [Boolean] whether the socket is readable
    def readable?
      (options.events & POLLIN).positive?
    end


    # Checks whether at least one message can be written to the socket without
    # blocking.
    # @return [Boolean] whether the socket is writable
    def writable?
      (options.events & POLLOUT).positive?
    end


    # Useful for registration in an event-loop.
    # @return [Integer]
    # @see OptionsAccessor#fd
    def fd
      options.fd
    end


    # @return [IO] IO for FD
    def to_io
      IO.for_fd fd, autoclose: false
    end


    # Used to access the options of a {Socket}.
    class OptionsAccessor

      # @return [Socket] whose options this {OptionsAccessor} instance
      #   is accessing
      attr_reader :zocket

      # @param zocket [Socket]
      def initialize(zocket)
        @zocket = zocket
      end


      # Fuzzy option getter. This is to make it easier when porting
      # applications from CZMQ libraries to CZTop.
      #
      # @param option_name [Symbol, String] case insensitive option name
      # @raise [NoMethodError] if option name can't be recognized
      def [](option_name)
        meth1 = :"#{option_name}"
        meth2 = :"#{option_name}?"

        if respond_to? meth1
          meth = meth1
        elsif respond_to? meth2
          meth = meth2
        else
          # NOTE: beware of predicates, especially #CURVE_server? & friends
          meth = public_methods.grep_v(/=$/)
                               .find { |m| m =~ /^#{option_name}\??$/i }
          raise NoMethodError, option_name if meth.nil?
        end

        __send__(meth)
      end


      # Fuzzy option setter. This is to make it easier when porting
      # applications from CZMQ libraries to CZTop.
      #
      # @param option_name [Symbol, String] case insensitive option name
      # @param new_value [String, Integer] new value
      # @raise [NoMethodError] if option name can't be recognized
      def []=(option_name, new_value)
        meth = :"#{option_name}="

        unless respond_to? meth
          meth = public_methods.find { |m| m =~ /^#{option_name}=$/i }
          raise NoMethodError, option_name if meth.nil?
        end

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

      # ZMQ_ROUTER_MANDATORY: Accept only routable messages on ROUTER sockets. Default is off.
      # @param bool [Boolean] whether to raise a SocketError if a message isn't routable
      #   (either if the that peer isn't connected or its SNDHWM is reached)
      # @see https://libzmq.readthedocs.io/en/latest/zmq_setsockopt.html#_zmq_router_mandatory_accept_only_routable_messages_on_router_sockets
      def router_mandatory=(bool)
        Zsock.set_router_mandatory(@zocket, bool ? 1 : 0)
        @router_mandatory = bool # NOTE: no way to read this option, so we need to remember
      end


      # @return [Boolean] whether ZMQ_ROUTER_MANDATORY has been set
      def router_mandatory?
        @router_mandatory
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
      # @see CZTop::ZsockOptions::POLLIN
      # @see CZTop::ZsockOptions::POLLOUT
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
