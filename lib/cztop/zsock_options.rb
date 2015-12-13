module CZTop
  # This module adds the ability to access options of a {Socket} or an
  # {Actor}.
  # @see http://api.zeromq.org/czmq3-0:zsock-option
  module ZsockOptions
    # Access to the options of this socket.
    # @return [Options]
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

      # @return [Integer]
      def sndhwm() Z.sndhwm(@zocket) end
      # @param value [Integer]
      def sndhwm=(value) Z.set_sndhwm(@zocket, value) end
      # @return [Integer]
      def rcvhwm() Z.rcvhwm(@zocket) end
      # @param value [Integer]
      def rcvhwm=(value) Z.set_rcvhwm(@zocket, value) end

# TODO: a reasonable subset of these
#//  Get socket options
#int zsock_tos (void *self);
#char * zsock_zap_domain (void *self);
#int zsock_mechanism (void *self);
#int zsock_plain_server (void *self);
#char * zsock_plain_username (void *self);
#char * zsock_plain_password (void *self);
#int zsock_curve_server (void *self);
#char * zsock_curve_publickey (void *self);
#char * zsock_curve_secretkey (void *self);
#char * zsock_curve_serverkey (void *self);
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
#int zsock_rcvtimeo (void *self);
#int zsock_sndtimeo (void *self);
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
#void zsock_set_zap_domain (void *self, const char * zap_domain);
#void zsock_set_plain_server (void *self, int plain_server);
#void zsock_set_plain_username (void *self, const char * plain_username);
#void zsock_set_plain_password (void *self, const char * plain_password);
#void zsock_set_curve_server (void *self, int curve_server);
#void zsock_set_curve_publickey (void *self, const char * curve_publickey);
#void zsock_set_curve_publickey_bin (void *self, const byte *curve_publickey);
#void zsock_set_curve_secretkey (void *self, const char * curve_secretkey);
#void zsock_set_curve_secretkey_bin (void *self, const byte *curve_secretkey);
#void zsock_set_curve_serverkey (void *self, const char * curve_serverkey);
#void zsock_set_curve_serverkey_bin (void *self, const byte *curve_serverkey);
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
#void zsock_set_rcvtimeo (void *self, int rcvtimeo);
#void zsock_set_sndtimeo (void *self, int sndtimeo);
#void zsock_set_xpub_verbose (void *self, int xpub_verbose);
#void zsock_set_tcp_keepalive (void *self, int tcp_keepalive);
#void zsock_set_tcp_keepalive_idle (void *self, int tcp_keepalive_idle);
#void zsock_set_tcp_keepalive_cnt (void *self, int tcp_keepalive_cnt);
#void zsock_set_tcp_keepalive_intvl (void *self, int tcp_keepalive_intvl);
#void zsock_set_tcp_accept_filter (void *self, const char * tcp_accept_filter);
    end
  end
end
