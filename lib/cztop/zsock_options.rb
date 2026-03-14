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

    # @api private
    POLLIN  = 1
    POLLOUT = 2

    include CZMQ::FFI

    # Checks whether there's a message that can be read from the socket
    # without blocking.
    # @return [Boolean] whether the socket is readable
    #
    def readable?
      (events & POLLIN).positive?
    end


    # Checks whether at least one message can be written to the socket without
    # blocking.
    # @return [Boolean] whether the socket is writable
    #
    def writable?
      (events & POLLOUT).positive?
    end


    # Useful for registration in an event-loop.
    # @return [Integer]
    #
    def fd
      Zsock.fd(self)
    end


    # @return [IO] IO for FD
    #
    def to_io
      IO.for_fd fd, autoclose: false
    end


    # @!group High Water Marks

    # @return [Integer] the send high water mark
    #
    def sndhwm
      Zsock.sndhwm(self)
    end


    # @param value [Integer] the new send high water mark.
    #
    def sndhwm=(value)
      Zsock.set_sndhwm(self, value)
    end


    # @return [Integer] the receive high water mark
    #
    def rcvhwm
      Zsock.rcvhwm(self)
    end


    # @param value [Integer] the new receive high water mark
    #
    def rcvhwm=(value)
      Zsock.set_rcvhwm(self, value)
    end

    # @!endgroup

    # @!group Send and Receive Timeouts

    # @return [Numeric, nil] the receive timeout in seconds, or nil
    #   if blocking indefinitely (no timeout). 0 means nonblocking.
    #
    def recv_timeout
      value = Zsock.rcvtimeo(self)
      value == -1 ? nil : value / 1000.0
    end


    # @param timeout [Numeric, nil] new receive timeout in seconds,
    #   or nil to block indefinitely (no timeout). 0 means nonblocking.
    #
    def recv_timeout=(timeout)
      Zsock.set_rcvtimeo(self, timeout.nil? ? -1 : (timeout * 1000).to_i)
    end

    alias_method :read_timeout,  :recv_timeout
    alias_method :read_timeout=, :recv_timeout=


    # @return [Numeric, nil] the send timeout in seconds, or nil
    #   if blocking indefinitely (no timeout). 0 means nonblocking.
    #
    def send_timeout
      value = Zsock.sndtimeo(self)
      value == -1 ? nil : value / 1000.0
    end


    # @param timeout [Numeric, nil] new send timeout in seconds,
    #   or nil to block indefinitely (no timeout). 0 means nonblocking.
    #
    def send_timeout=(timeout)
      Zsock.set_sndtimeo(self, timeout.nil? ? -1 : (timeout * 1000).to_i)
    end

    alias_method :write_timeout,  :send_timeout
    alias_method :write_timeout=, :send_timeout=

    # @!endgroup

    # ZMQ_ROUTER_MANDATORY: Accept only routable messages on ROUTER sockets. Default is off.
    # @param bool [Boolean] whether to raise a SocketError if a message isn't routable
    #   (either if the that peer isn't connected or its SNDHWM is reached)
    # @see https://libzmq.readthedocs.io/en/latest/zmq_setsockopt.html#_zmq_router_mandatory_accept_only_routable_messages_on_router_sockets
    #
    def router_mandatory=(bool)
      Zsock.set_router_mandatory(self, bool ? 1 : 0)
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
      Zsock.identity(self).read_string
    end


    # @param identity [String] new socket identity
    # @raise [ArgumentError] if identity is invalid
    #
    def identity=(identity)
      raise ArgumentError, 'zero-length identity' if identity.bytesize.zero?
      raise ArgumentError, 'identity too long' if identity.bytesize > 255
      raise ArgumentError, 'invalid identity' if identity.start_with? "\0"

      Zsock.set_identity(self, identity)
    end


    # @return [Integer] current value of Type of Service
    #
    def tos
      Zsock.tos(self)
    end


    # @param new_value [Integer] new value for Type of Service
    #
    def tos=(new_value)
      raise ArgumentError, 'invalid TOS' unless new_value >= 0

      Zsock.set_tos(self, new_value)
    end


    # @return [Numeric] current value of Heartbeat IVL in seconds
    #
    def heartbeat_ivl
      Zsock.heartbeat_ivl(self) / 1000.0
    end


    # @param new_value [Numeric] new value for Heartbeat IVL in seconds
    #
    def heartbeat_ivl=(new_value)
      raise ArgumentError, 'invalid IVL' unless new_value >= 0

      Zsock.set_heartbeat_ivl(self, (new_value * 1000).to_i)
    end


    # @return [Numeric] current value of Heartbeat TTL in seconds
    #
    def heartbeat_ttl
      Zsock.heartbeat_ttl(self) / 1000.0
    end


    # @param new_value [Numeric] new value for Heartbeat TTL in seconds
    # @note The value will internally be rounded to the nearest decisecond.
    #   So a value of less than 0.1 will have no effect.
    #
    def heartbeat_ttl=(new_value)
      raise ArgumentError, "invalid TTL: #{new_value}" unless new_value.is_a? Numeric
      ms = (new_value * 1000).to_i
      raise ArgumentError, "TTL out of range: #{new_value}" unless (0..65_536).include? ms

      Zsock.set_heartbeat_ttl(self, ms)
    end


    # Returns the heartbeat timeout in seconds, or `nil` if not
    # explicitly set. When `nil`, libzmq uses {#heartbeat_ivl} as the
    # timeout (i.e. `-1` in the raw option means "use IVL").
    #
    # @return [Numeric, nil] timeout in seconds, or nil if unset
    #
    def heartbeat_timeout
      value = Zsock.heartbeat_timeout(self)
      value == -1 ? nil : value / 1000.0
    end


    # @param new_value [Numeric, nil] new value for Heartbeat Timeout in
    #   seconds, or nil to reset to default (use {#heartbeat_ivl})
    #
    def heartbeat_timeout=(new_value)
      if new_value.nil?
        Zsock.set_heartbeat_timeout(self, 0)
        return
      end

      raise ArgumentError, 'invalid timeout' unless new_value >= 0

      Zsock.set_heartbeat_timeout(self, (new_value * 1000).to_i)
    end


    # @return [Numeric, nil] linger period in seconds, or nil to
    #   wait indefinitely. 0 means no waiting (default).
    #
    def linger
      value = Zsock.linger(self)
      value == -1 ? nil : value / 1000.0
    end


    # Sets how long to wait while closing/disconnecting a socket if
    # there are outstanding messages to send.
    #
    # @param new_value [Numeric, nil] linger period in seconds,
    #   or nil to wait indefinitely. 0 means no waiting (default).
    #
    def linger=(new_value)
      Zsock.set_linger(self, new_value.nil? ? -1 : (new_value * 1000).to_i)
    end


    # @return [Boolean] current value of ipv6
    #
    def ipv6?
      Zsock.ipv6(self) != 0
    end


    # Set the IPv6 option for the socket. A value of true means IPv6 is
    # enabled on the socket, while false means the socket will use only
    # IPv4.  When IPv6 is enabled the socket will connect to, or accept
    # connections from, both IPv4 and IPv6 hosts.
    # Default is false.
    # @param new_value [Boolean] new value for ipv6
    #
    def ipv6=(new_value)
      Zsock.set_ipv6(self, new_value ? 1 : 0)
    end


    # @return [Numeric, nil] reconnect interval in seconds, or nil
    #   if reconnection is disabled
    #
    def reconnect_ivl
      value = Zsock.reconnect_ivl(self)
      value == -1 ? nil : value / 1000.0
    end


    # @param new_value [Numeric, nil] reconnect interval in seconds,
    #   or nil to disable reconnection
    #
    def reconnect_ivl=(new_value)
      Zsock.set_reconnect_ivl(self, new_value.nil? ? -1 : (new_value * 1000).to_i)
    end


    # @return [Numeric, nil] maximum reconnect interval in seconds, or nil
    #   if no maximum is set (uses fixed {#reconnect_ivl})
    #
    def reconnect_ivl_max
      value = Zsock.reconnect_ivl_max(self)
      value.zero? ? nil : value / 1000.0
    end


    # Sets the maximum reconnect interval for exponential backoff.
    # When set, reconnect intervals grow from {#reconnect_ivl} up to this
    # maximum. Set to nil to disable backoff (use fixed interval).
    #
    # @param new_value [Numeric, nil] max reconnect interval in seconds,
    #   or nil to disable backoff
    #
    def reconnect_ivl_max=(new_value)
      Zsock.set_reconnect_ivl_max(self, new_value.nil? ? 0 : (new_value * 1000).to_i)
    end


    # @return [Integer, nil] maximum inbound message size in bytes,
    #   or nil if unlimited (the default, -1 in libzmq)
    #
    def max_msg_size
      value = Zsock.maxmsgsize(self)
      value == -1 ? nil : value
    end


    # Sets the maximum inbound message size. Messages larger than this are
    # dropped and the connection is disconnected. Useful for DoS protection.
    #
    # @param new_value [Integer, nil] max size in bytes, or nil for unlimited
    #
    def max_msg_size=(new_value)
      Zsock.set_maxmsgsize(self, new_value.nil? ? -1 : new_value)
    end


    # @return [Boolean] whether the socket queues messages only for
    #   completed connections
    #
    def immediate?
      Zsock.immediate(self) == 1
    end


    # When true, the socket queues messages only for completed connections
    # (i.e. peers that have finished the ZMTP handshake). When false
    # (default), messages may be queued for connections that haven't
    # completed yet, risking message loss if the peer never connects.
    #
    # @param bool [Boolean] whether to enable immediate mode
    #
    def immediate=(bool)
      Zsock.set_immediate(self, bool ? 1 : 0)
    end


    # @return [Boolean] whether conflate mode is enabled
    # @note There is no libzmq getter for this option, so the value
    #   is tracked locally.
    #
    def conflate?
      !!@conflate
    end


    # When true, the socket keeps only the last message in its
    # inbound/outbound queue, discarding older messages. Useful for
    # "last value cache" semantics in PUB/SUB or PUSH/PULL pipelines
    # where only the latest value matters.
    #
    # @param bool [Boolean] whether to enable conflate mode
    # @note Must be set before connecting/binding.
    #
    def conflate=(bool)
      Zsock.set_conflate(self, bool ? 1 : 0)
      @conflate = bool
    end

    # @!group TCP Keepalive

    # @return [Boolean, nil] TCP keepalive override: true = enabled,
    #   false = disabled, nil = OS default (-1)
    #
    def tcp_keepalive
      value = Zsock.tcp_keepalive(self)
      case value
      when -1 then nil
      when 0  then false
      when 1  then true
      end
    end


    # Overrides the OS default for TCP keepalive on this socket.
    #
    # @param value [Boolean, nil] true = enable, false = disable,
    #   nil = use OS default
    #
    def tcp_keepalive=(value)
      int = case value
            when nil   then -1
            when false then 0
            when true  then 1
            end
      Zsock.set_tcp_keepalive(self, int)
    end


    # @return [Integer, nil] TCP keepalive idle time in seconds,
    #   or nil for OS default
    #
    def tcp_keepalive_idle
      value = Zsock.tcp_keepalive_idle(self)
      value == -1 ? nil : value
    end


    # @param value [Integer, nil] idle time in seconds before first
    #   keepalive probe, or nil for OS default
    #
    def tcp_keepalive_idle=(value)
      Zsock.set_tcp_keepalive_idle(self, value.nil? ? -1 : value)
    end


    # @return [Integer, nil] number of keepalive probes before declaring
    #   the connection dead, or nil for OS default
    #
    def tcp_keepalive_cnt
      value = Zsock.tcp_keepalive_cnt(self)
      value == -1 ? nil : value
    end


    # @param value [Integer, nil] probe count, or nil for OS default
    #
    def tcp_keepalive_cnt=(value)
      Zsock.set_tcp_keepalive_cnt(self, value.nil? ? -1 : value)
    end


    # @return [Integer, nil] interval in seconds between keepalive probes,
    #   or nil for OS default
    #
    def tcp_keepalive_intvl
      value = Zsock.tcp_keepalive_intvl(self)
      value == -1 ? nil : value
    end


    # @param value [Integer, nil] probe interval in seconds,
    #   or nil for OS default
    #
    def tcp_keepalive_intvl=(value)
      Zsock.set_tcp_keepalive_intvl(self, value.nil? ? -1 : value)
    end

    # @!endgroup


    private


    # @return [Integer] socket events (readable/writable)
    # @see CZTop::ZsockOptions::POLLIN
    # @see CZTop::ZsockOptions::POLLOUT
    #
    def events
      Zsock.events(self)
    end

  end
end
