module CZTop
  # This module adds the ability to access options of a {Socket} or an
  # {Actor}.
  # @see http://api.zeromq.org/czmq3-0:zsock-option
  module ZsockOptions
    # Access to the options of this socket.
    # @return [OptionsAccessor]
    def options
      OptionsAccessor.new(self)
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

      include CZMQ::FFI

      # @return [Integer] the send high water mark
      def sndhwm() Zsock.sndhwm(@zocket) end
      # @param value [Integer] the new send high water mark.
      def sndhwm=(value) Zsock.set_sndhwm(@zocket, value) end
      # @return [Integer] the receive high water mark
      def rcvhwm() Zsock.rcvhwm(@zocket) end
      # @param value [Integer] the new receive high water mark
      def rcvhwm=(value) Zsock.set_rcvhwm(@zocket, value) end

      # @!group (CURVE) Security

      # @return [Boolean] whether this zocket is a CURVE server
      def CURVE_server?() Zsock.curve_server(@zocket) > 0 end

      # Make this zocket a CURVE server.
      # @param bool [Boolean]
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
          raise ArgumentError, "invalid server key: %p" % key
        end
      end

      # supported security mechanisms and their macro value equivalent
      MECHANISMS = {
        0 => :NULL,  # ZMQ_NULL
        1 => :PLAIN, # ZMQ_PLAIN
        2 => :CURVE, # ZMQ_CURVE
        3 => :GSSAPI # ZMQ_GSSAPI
      }

      # @return [Symbol] the current security mechanism in use
      # @note This is automatically set through the use of CURVE certificates,
      #   etc
      def mechanism
        #int zsock_mechanism (void *self);
        code = Zsock.mechanism(@zocket)
        MECHANISMS[code] or
          raise "unknown ZMQ security mechanism code: %i" % code
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
        raise ArgumentError, "domain too long" if domain.bytesize > 254
        Zsock.set_zap_domain(@zocket, domain)
      end

      # @return [Boolean] whether this zocket is a PLAIN server
      def PLAIN_server?() Zsock.plain_server(@zocket) > 0 end

      # Make this zocket a PLAIN server.
      # @param bool [Boolean]
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

      # @return [Integer] the timeout when receiving a message
      def rcvtimeo() Zsock.rcvtimeo(@zocket) end
      # @param timeout [Integer] new timeout
      def rcvtimeo=(timeout) Zsock.set_rcvtimeo(@zocket, timeout) end

      # @return [Integer] the timeout when sending a message
      def sndtimeo() Zsock.sndtimeo(@zocket) end
      # @param timeout [Integer] new timeout
      def sndtimeo=(timeout) Zsock.set_sndtimeo(@zocket, timeout) end

      # Accept only routable messages on ROUTER sockets. Default is off.
      # @param bool [Boolean] whether to error if a message isn't routable
      #   (either if the that peer isn't connected or its SNDHWM is reached)
      def router_mandatory=(bool)
        Zsock.set_router_mandatory(@zocket, bool ? 1 : 0)
      end

      # @return [String] current socket identity
      def identity() Zsock.identity(@zocket).read_string end
      # @param identity [String] new socket identity
      def identity=(identity) Zsock.set_identity(@zocket, identity) end

# TODO: a reasonable subset of these
#//  Get socket options
#int zsock_tos (void *self);
#int zsock_gssapi_server (void *self);
#int zsock_gssapi_plaintext (void *self);
#char * zsock_gssapi_principal (void *self);
#char * zsock_gssapi_service_principal (void *self);
#int zsock_ipv6 (void *self);
#int zsock_immediate (void *self);
#int zsock_ipv4only (void *self);
#int zsock_type (void *self);
#int zsock_affinity (void *self);
#int zsock_rate (void *self);
#int zsock_recovery_ivl (void *self);
#int zsock_sndbuf (void *self);
#int zsock_rcvbuf (void *self);
#int zsock_linger (void *self);
#int zsock_reconnect_ivl (void *self);
#int zsock_reconnect_ivl_max (void *self);
#int zsock_backlog (void *self);
#int zsock_maxmsgsize (void *self);
#int zsock_multicast_hops (void *self);
#int zsock_tcp_keepalive (void *self);
#int zsock_tcp_keepalive_idle (void *self);
#int zsock_tcp_keepalive_cnt (void *self);
#int zsock_tcp_keepalive_intvl (void *self);
#char * zsock_tcp_accept_filter (void *self);
#int zsock_rcvmore (void *self);
#SOCKET zsock_fd (void *self);
#int zsock_events (void *self);
#char * zsock_last_endpoint (void *self);
#
#//  Set socket options
#void zsock_set_tos (void *self, int tos);
#void zsock_set_router_handover (void *self, int router_handover);
#void zsock_set_probe_router (void *self, int probe_router);
#void zsock_set_req_relaxed (void *self, int req_relaxed);
#void zsock_set_req_correlate (void *self, int req_correlate);
#void zsock_set_conflate (void *self, int conflate);
#void zsock_set_gssapi_server (void *self, int gssapi_server);
#void zsock_set_gssapi_plaintext (void *self, int gssapi_plaintext);
#void zsock_set_gssapi_principal (void *self, const char * gssapi_principal);
#void zsock_set_gssapi_service_principal (void *self, const char * gssapi_service_principal);
#void zsock_set_ipv6 (void *self, int ipv6);
#void zsock_set_immediate (void *self, int immediate);
#void zsock_set_router_raw (void *self, int router_raw);
#void zsock_set_ipv4only (void *self, int ipv4only);
#void zsock_set_delay_attach_on_connect (void *self, int delay_attach_on_connect);
#void zsock_set_affinity (void *self, int affinity);
#void zsock_set_subscribe (void *self, const char * subscribe);
#void zsock_set_unsubscribe (void *self, const char * unsubscribe);
#void zsock_set_rate (void *self, int rate);
#void zsock_set_recovery_ivl (void *self, int recovery_ivl);
#void zsock_set_sndbuf (void *self, int sndbuf);
#void zsock_set_rcvbuf (void *self, int rcvbuf);
#void zsock_set_linger (void *self, int linger);
#void zsock_set_reconnect_ivl (void *self, int reconnect_ivl);
#void zsock_set_reconnect_ivl_max (void *self, int reconnect_ivl_max);
#void zsock_set_backlog (void *self, int backlog);
#void zsock_set_maxmsgsize (void *self, int maxmsgsize);
#void zsock_set_multicast_hops (void *self, int multicast_hops);
#void zsock_set_xpub_verbose (void *self, int xpub_verbose);
#void zsock_set_tcp_keepalive (void *self, int tcp_keepalive);
#void zsock_set_tcp_keepalive_idle (void *self, int tcp_keepalive_idle);
#void zsock_set_tcp_keepalive_cnt (void *self, int tcp_keepalive_cnt);
#void zsock_set_tcp_keepalive_intvl (void *self, int tcp_keepalive_intvl);
#void zsock_set_tcp_accept_filter (void *self, const char * tcp_accept_filter);
    end
  end
end
