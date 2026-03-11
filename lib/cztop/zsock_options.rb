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
    #
    def options
      @options ||= OptionsAccessor.new(self)
    end


    # @api private
    POLLIN  = 1
    POLLOUT = 2

    # Checks whether there's a message that can be read from the socket
    # without blocking.
    # @return [Boolean] whether the socket is readable
    #
    def readable?
      (options.events & POLLIN).positive?
    end


    # Checks whether at least one message can be written to the socket without
    # blocking.
    # @return [Boolean] whether the socket is writable
    #
    def writable?
      (options.events & POLLOUT).positive?
    end


    # Useful for registration in an event-loop.
    # @return [Integer]
    # @see OptionsAccessor#fd
    #
    def fd
      options.fd
    end


    # @return [IO] IO for FD
    #
    def to_io
      IO.for_fd fd, autoclose: false
    end


    # Used to access the options of a {Socket}.
    #
    class OptionsAccessor

      # @return [Socket] whose options this {OptionsAccessor} instance
      #   is accessing
      #
      attr_reader :socket

      # @param socket [Socket]
      #
      def initialize(socket)
        @socket = socket
      end


      # Fuzzy option getter. This is to make it easier when porting
      # applications from CZMQ libraries to CZTop.
      #
      # @param option_name [Symbol, String] case insensitive option name
      # @raise [NoMethodError] if option name can't be recognized
      #
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
      #
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
      #
      def sndhwm
        Zsock.sndhwm(@socket)
      end


      # @param value [Integer] the new send high water mark.
      #
      def sndhwm=(value)
        Zsock.set_sndhwm(@socket, value)
      end


      # @return [Integer] the receive high water mark
      #
      def rcvhwm
        Zsock.rcvhwm(@socket)
      end


      # @param value [Integer] the new receive high water mark
      #
      def rcvhwm=(value)
        Zsock.set_rcvhwm(@socket, value)
      end

      # @!endgroup

      # @!group Send and Receive Timeouts

      # @return [Integer, nil] the receive timeout in milliseconds, or nil
      #   if blocking indefinitely (no timeout). 0 means nonblocking.
      #
      def rcvtimeo
        value = Zsock.rcvtimeo(@socket)
        value == -1 ? nil : value
      end


      # @param timeout [Integer, nil] new receive timeout in milliseconds,
      #   or nil to block indefinitely (no timeout). 0 means nonblocking.
      #
      def rcvtimeo=(timeout)
        Zsock.set_rcvtimeo(@socket, timeout || -1)
      end


      # @return [Integer, nil] the send timeout in milliseconds, or nil
      #   if blocking indefinitely (no timeout). 0 means nonblocking.
      #
      def sndtimeo
        value = Zsock.sndtimeo(@socket)
        value == -1 ? nil : value
      end


      # @param timeout [Integer, nil] new send timeout in milliseconds,
      #   or nil to block indefinitely (no timeout). 0 means nonblocking.
      #
      def sndtimeo=(timeout)
        Zsock.set_sndtimeo(@socket, timeout || -1)
      end

      # @!endgroup

      # ZMQ_ROUTER_MANDATORY: Accept only routable messages on ROUTER sockets. Default is off.
      # @param bool [Boolean] whether to raise a SocketError if a message isn't routable
      #   (either if the that peer isn't connected or its SNDHWM is reached)
      # @see https://libzmq.readthedocs.io/en/latest/zmq_setsockopt.html#_zmq_router_mandatory_accept_only_routable_messages_on_router_sockets
      #
      def router_mandatory=(bool)
        Zsock.set_router_mandatory(@socket, bool ? 1 : 0)
        @router_mandatory = bool # NOTE: no way to read this option, so we need to remember
      end


      # @return [Boolean] whether ZMQ_ROUTER_MANDATORY has been set
      #
      def router_mandatory?
        !!@router_mandatory
      end


      # @return [String] current socket identity
      #
      def identity
        Zsock.identity(@socket).read_string
      end


      # @param identity [String] new socket identity
      # @raise [ArgumentError] if identity is invalid
      #
      def identity=(identity)
        raise ArgumentError, 'zero-length identity' if identity.bytesize.zero?
        raise ArgumentError, 'identity too long' if identity.bytesize > 255
        raise ArgumentError, 'invalid identity' if identity.start_with? "\0"

        Zsock.set_identity(@socket, identity)
      end


      # @return [Integer] current value of Type of Service
      #
      def tos
        Zsock.tos(@socket)
      end


      # @param new_value [Integer] new value for Type of Service
      #
      def tos=(new_value)
        raise ArgumentError, 'invalid TOS' unless new_value >= 0

        Zsock.set_tos(@socket, new_value)
      end


      # @return [Integer] current value of Heartbeat IVL
      #
      def heartbeat_ivl
        Zsock.heartbeat_ivl(@socket)
      end


      # @param new_value [Integer] new value for Heartbeat IVL
      #
      def heartbeat_ivl=(new_value)
        raise ArgumentError, 'invalid IVL' unless new_value >= 0

        Zsock.set_heartbeat_ivl(@socket, new_value)
      end


      # @return [Integer] current value of Heartbeat TTL, in milliseconds
      #
      def heartbeat_ttl
        Zsock.heartbeat_ttl(@socket)
      end


      # @param new_value [Integer] new value for Heartbeat TTL, in
      #   milliseconds
      # @note The value will internally be rounded to the nearest decisecond.
      #   So a value of less than 100 will have no effect.
      #
      def heartbeat_ttl=(new_value)
        raise ArgumentError, "invalid TTL: #{new_value}" unless new_value.is_a? Integer
        raise ArgumentError, "TTL out of range: #{new_value}" unless (0..65_536).include? new_value

        Zsock.set_heartbeat_ttl(@socket, new_value)
      end


      # Returns the heartbeat timeout in milliseconds, or `nil` if not
      # explicitly set. When `nil`, libzmq uses {#heartbeat_ivl} as the
      # timeout (i.e. `-1` in the raw option means "use IVL").
      #
      # @return [Integer, nil] timeout in ms, or nil if unset
      #
      def heartbeat_timeout
        value = Zsock.heartbeat_timeout(@socket)
        value == -1 ? nil : value
      end


      # @param new_value [Integer, nil] new value for Heartbeat Timeout in
      #   milliseconds, or nil to reset to default (use {#heartbeat_ivl})
      #
      def heartbeat_timeout=(new_value)
        if new_value.nil?
          Zsock.set_heartbeat_timeout(@socket, 0)
          return
        end

        raise ArgumentError, 'invalid timeout' unless new_value >= 0

        Zsock.set_heartbeat_timeout(@socket, new_value)
      end


      # @return [Integer, nil] linger period in milliseconds, or nil to
      #   wait indefinitely. 0 means no waiting (default).
      #
      def linger
        value = Zsock.linger(@socket)
        value == -1 ? nil : value
      end


      # Sets how long to wait while closing/disconnecting a socket if
      # there are outstanding messages to send.
      #
      # @param new_value [Integer, nil] linger period in milliseconds,
      #   or nil to wait indefinitely. 0 means no waiting (default).
      #
      def linger=(new_value)
        Zsock.set_linger(@socket, new_value || -1)
      end


      # @return [Boolean] current value of ipv6
      #
      def ipv6?
        Zsock.ipv6(@socket) != 0
      end


      # Set the IPv6 option for the socket. A value of true means IPv6 is
      # enabled on the socket, while false means the socket will use only
      # IPv4.  When IPv6 is enabled the socket will connect to, or accept
      # connections from, both IPv4 and IPv6 hosts.
      # Default is false.
      # @param new_value [Boolean] new value for ipv6
      #
      def ipv6=(new_value)
        Zsock.set_ipv6(@socket, new_value ? 1 : 0)
      end


      # @return [Integer] socket file descriptor
      #
      def fd
        Zsock.fd(@socket)
      end


      # @return [Integer] socket events (readable/writable)
      # @see CZTop::ZsockOptions::POLLIN
      # @see CZTop::ZsockOptions::POLLOUT
      #
      def events
        Zsock.events(@socket)
      end


      # @return [Integer, nil] reconnect interval in milliseconds, or nil
      #   if reconnection is disabled
      #
      def reconnect_ivl
        value = Zsock.reconnect_ivl(@socket)
        value == -1 ? nil : value
      end


      # @param new_value [Integer, nil] reconnect interval in milliseconds,
      #   or nil to disable reconnection
      #
      def reconnect_ivl=(new_value)
        Zsock.set_reconnect_ivl(@socket, new_value || -1)
      end

    end

  end
end
