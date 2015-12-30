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

      # just to shorten the lines
      Z = ::CZMQ::FFI::Zsock

      # @return [Integer] the send high water mark
      def sndhwm() Z.sndhwm(@zocket) end
      # @param value [Integer] the new send high water mark.
      def sndhwm=(value) Z.set_sndhwm(@zocket, value) end
      # @return [Integer] the receive high water mark
      def rcvhwm() Z.rcvhwm(@zocket) end
      # @param value [Integer] the new receive high water mark
      def rcvhwm=(value) Z.set_rcvhwm(@zocket, value) end

      # @!group (CURVE) Security

      # @return [Boolean] whether this zocket is a CURVE server
      def curve_server?() Z.curve_server(@zocket) > 0 end

      # Make this zocket a CURVE server.
      # @param bool [Boolean]
      def curve_server=(bool) Z.set_curve_server(@zocket, bool ? 1 : 0) end

      # @return [String] Z85 encoded server key set
      # @return [nil] if the current mechanism isn't CURVE or CURVE isn't
      #   supported
      def curve_serverkey()
        return nil if mechanism != :curve
        ptr = Z.curve_serverkey(@zocket)
        return nil if ptr.null?
        ptr.read_string
      end

      # Sets the server's public key, so the zocket can authenticate the
      # remote server.
      # @param key [String] Z85 (40 bytes) or binary (32 bytes) server key
      # @raise [ArgumentError] if key has wrong size
      def curve_serverkey=(key)
        if key.bytesize == 40
          Z.set_curve_serverkey(@zocket, key)
        elsif key.bytesize == 32
          ptr = ::FFI::MemoryPointer.from_string(key)
          Z.set_curve_serverkey_bin(@zocket, ptr)
        else
          raise ArgumentError, "invalid server key: %p" % key
        end
      end

      # supported security mechanisms and their macro value equivalent
      MECHANISMS = {
        0 => :null,  # ZMQ_NULL
        1 => :plain, # ZMQ_PLAIN
        2 => :curve, # ZMQ_CURVE
        3 => :gssapi # ZMQ_GSSAPI
      }

      # @return [Symbol] the current security mechanism in use
      # @note This is automatically set through the use of CURVE certificates,
      #   etc
      def mechanism
        #int zsock_mechanism (void *self);
        code = Z.mechanism(@zocket)
        MECHANISMS[code] or
          raise "unknown ZMQ security mechanism code: %i" % code
      end

      # Sets the secret key, so the zocket can authenticate itself to a remote
      # server or client.
      # @param key [String] Z85 (40 bytes) or binary (32 bytes) secret key
      # @raise [ArgumentError] if key has wrong size
      # TODO: does it also set the public key?
      def curve_secretkey=(key)
        if key.bytesize == 40
          Z.set_curve_secretkey(@zocket, key)
        elsif key.bytesize == 32
          ptr = ::FFI::MemoryPointer.from_string(key)
          Z.set_curve_secretkey_bin(@zocket, ptr)
        else
          raise ArgumentError, "invalid secret key: %p" % key
        end
      end

      # @return [String] Z85 encoded secret key set
      # @return [nil] if the current mechanism isn't CURVE or CURVE isn't
      #   supported
      # TODO: check if empty string is returned if mechanism == curve, but
      # secret key not set
      def curve_secretkey
        return nil if mechanism != :curve
        ptr = Z.curve_secretkey(@zocket)
        return nil if ptr.null?
        ptr.read_string
      end

#      def curve_publickey
#        return nil if mechanism != :curve
#        ptr = Z.curve_publickey(@zocket)
#        return nil if ptr.null?
#        ptr.read_string
#      end


#char * zsock_curve_publickey (void *self);
#void zsock_set_curve_publickey (void *self, const char * curve_publickey);
#void zsock_set_curve_publickey_bin (void *self, const byte *curve_publickey);

      # Gets the ZAP domain used for authentication.
      # @see http://rfc.zeromq.org/spec:27
      # @return [String]
      def zap_domain
#char * zsock_zap_domain (void *self);
        Z.zap_domain(@zocket).read_string
      end
      # Sets the ZAP domain used for authentication.
      # @param domain [String] the new ZAP domain
      def zap_domain=(domain)
#void zsock_set_zap_domain (void *self, const char * zap_domain);
        raise ArgumentError, "domain too long" if domain.bytesize > 254
        Z.set_zap_domain(@zocket, domain)
      end

      # @!endgroup

      # @return [Integer] the timeout when receiving a message
      def rcvtimeo
        #int zsock_rcvtimeo (void *self);
        Z.rcvtimeo(@zocket)
      end
      # @param timeout [Integer] new timeout
      def rcvtimeo=(timeout)
        #void zsock_set_rcvtimeo (void *self, int rcvtimeo);
        Z.set_rcvtimeo(@zocket, timeout)
      end

      # @return [Integer] the timeout when sending a message
      def sndtimeo
        #int zsock_sndtimeo (void *self);
        Z.sndtimeo(@zocket)
      end
      # @param timeout [Integer] new timeout
      def sndtimeo=(timeout)
        #void zsock_set_sndtimeo (void *self, int sndtimeo);
        Z.set_sndtimeo(@zocket, timeout)
      end

# TODO: a reasonable subset of these
#//  Get socket options
#int zsock_tos (void *self);
#int zsock_plain_server (void *self);
#char * zsock_plain_username (void *self);
#char * zsock_plain_password (void *self);
#int zsock_gssapi_server (void *self);
#int zsock_gssapi_plaintext (void *self);
#char * zsock_gssapi_principal (void *self);
#char * zsock_gssapi_service_principal (void *self);
#int zsock_ipv6 (void *self);
#int zsock_immediate (void *self);
#int zsock_ipv4only (void *self);
#int zsock_type (void *self);
#int zsock_affinity (void *self);
#char * zsock_identity (void *self);
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
#void zsock_set_router_mandatory (void *self, int router_mandatory);
#void zsock_set_probe_router (void *self, int probe_router);
#void zsock_set_req_relaxed (void *self, int req_relaxed);
#void zsock_set_req_correlate (void *self, int req_correlate);
#void zsock_set_conflate (void *self, int conflate);
#void zsock_set_plain_server (void *self, int plain_server);
#void zsock_set_plain_username (void *self, const char * plain_username);
#void zsock_set_plain_password (void *self, const char * plain_password);
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
#void zsock_set_identity (void *self, const char * identity);
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
