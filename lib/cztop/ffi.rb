# frozen_string_literal: true

require 'ffi'

module CZMQ
  module FFI
    extend ::FFI::Library

    ffi_lib 'czmq', 'zmq'

    # -----------------------------------------------------------------
    # libzmq functions
    # -----------------------------------------------------------------
    attach_function :zmq_errno,    [], :int
    attach_function :zmq_strerror, [:int], :string
    attach_function :zmq_version,  [:pointer, :pointer, :pointer], :void

    # -----------------------------------------------------------------
    # zsys functions
    # -----------------------------------------------------------------
    attach_function :zsys_has_curve,       [], :bool
    attach_function :zsys_handler_set,     [:pointer], :void
    attach_function :zsys_set_logstream,   [:pointer], :void
    attach_function :zsys_version,         [:pointer, :pointer, :pointer], :void

    # -----------------------------------------------------------------
    # zsock functions
    # -----------------------------------------------------------------
    opts = { blocking: true }

    attach_function :zsock_new,            [:int], :pointer, **opts
    attach_function :zsock_destroy,        [:pointer], :void, **opts

    attach_function :zsock_new_req,        [:string], :pointer, **opts
    attach_function :zsock_new_rep,        [:string], :pointer, **opts
    attach_function :zsock_new_dealer,     [:string], :pointer, **opts
    attach_function :zsock_new_router,     [:string], :pointer, **opts
    attach_function :zsock_new_pub,        [:string], :pointer, **opts
    attach_function :zsock_new_sub,        [:string, :string], :pointer, **opts
    attach_function :zsock_new_xpub,       [:string], :pointer, **opts
    attach_function :zsock_new_xsub,       [:string], :pointer, **opts
    attach_function :zsock_new_push,       [:string], :pointer, **opts
    attach_function :zsock_new_pull,       [:string], :pointer, **opts
    attach_function :zsock_new_pair,       [:string], :pointer, **opts
    attach_function :zsock_new_stream,     [:string], :pointer, **opts

    attach_function :zsock_endpoint,       [:pointer], :string, **opts
    attach_function :zsock_connect,        [:pointer, :string, :varargs], :int, **opts
    attach_function :zsock_disconnect,     [:pointer, :string, :varargs], :int, **opts
    attach_function :zsock_bind,           [:pointer, :string, :varargs], :int, **opts
    attach_function :zsock_unbind,         [:pointer, :string, :varargs], :int, **opts
    attach_function :zsock_signal,         [:pointer, :uchar], :int, **opts
    attach_function :zsock_wait,           [:pointer], :int, **opts
    attach_function :zsock_resolve,        [:pointer], :pointer, **opts
    attach_function :zsock_set_unbounded,  [:pointer], :void, **opts

    attach_function :zsock_set_subscribe,   [:pointer, :string], :void, **opts
    attach_function :zsock_set_unsubscribe, [:pointer, :string], :void, **opts

    # zsock_send is variadic: int zsock_send(void *self, const char *picture, ...)
    begin
      attach_function :zsock_send_picture,   :zsock_send, [:pointer, :string, :varargs], :int, **opts
    rescue ::FFI::NotFoundError; end

    # zsock option getters
    attach_function :zsock_sndhwm,           [:pointer], :int, **opts
    attach_function :zsock_rcvhwm,           [:pointer], :int, **opts
    attach_function :zsock_mechanism,        [:pointer], :int, **opts
    attach_function :zsock_curve_server,     [:pointer], :int, **opts
    attach_function :zsock_curve_serverkey,  [:pointer], :pointer, **opts
    attach_function :zsock_curve_secretkey,  [:pointer], :pointer, **opts
    attach_function :zsock_curve_publickey,  [:pointer], :pointer, **opts
    attach_function :zsock_zap_domain,       [:pointer], :pointer, **opts
    attach_function :zsock_plain_server,     [:pointer], :int, **opts
    attach_function :zsock_plain_username,   [:pointer], :pointer, **opts
    attach_function :zsock_plain_password,   [:pointer], :pointer, **opts
    attach_function :zsock_rcvtimeo,         [:pointer], :int, **opts
    attach_function :zsock_sndtimeo,         [:pointer], :int, **opts
    attach_function :zsock_identity,         [:pointer], :pointer, **opts
    attach_function :zsock_tos,              [:pointer], :int, **opts
    attach_function :zsock_heartbeat_ivl,    [:pointer], :int, **opts
    attach_function :zsock_heartbeat_ttl,    [:pointer], :int, **opts
    attach_function :zsock_heartbeat_timeout, [:pointer], :int, **opts
    attach_function :zsock_linger,           [:pointer], :int, **opts
    attach_function :zsock_ipv6,             [:pointer], :int, **opts
    attach_function :zsock_fd,               [:pointer], :int, **opts
    attach_function :zsock_events,           [:pointer], :int, **opts
    attach_function :zsock_reconnect_ivl,    [:pointer], :int, **opts

    # zsock option setters
    attach_function :zsock_set_sndhwm,           [:pointer, :int], :void, **opts
    attach_function :zsock_set_rcvhwm,           [:pointer, :int], :void, **opts
    attach_function :zsock_set_curve_server,      [:pointer, :int], :void, **opts
    attach_function :zsock_set_curve_serverkey,   [:pointer, :string], :void, **opts
    attach_function :zsock_set_curve_serverkey_bin, [:pointer, :pointer], :void, **opts
    attach_function :zsock_set_zap_domain,        [:pointer, :string], :void, **opts
    attach_function :zsock_set_plain_server,      [:pointer, :int], :void, **opts
    attach_function :zsock_set_plain_username,    [:pointer, :string], :void, **opts
    attach_function :zsock_set_plain_password,    [:pointer, :string], :void, **opts
    attach_function :zsock_set_rcvtimeo,          [:pointer, :int], :void, **opts
    attach_function :zsock_set_sndtimeo,          [:pointer, :int], :void, **opts
    attach_function :zsock_set_router_mandatory,  [:pointer, :int], :void, **opts
    attach_function :zsock_set_identity,          [:pointer, :string], :void, **opts
    attach_function :zsock_set_tos,               [:pointer, :int], :void, **opts
    attach_function :zsock_set_heartbeat_ivl,     [:pointer, :int], :void, **opts
    attach_function :zsock_set_heartbeat_ttl,     [:pointer, :int], :void, **opts
    attach_function :zsock_set_heartbeat_timeout, [:pointer, :int], :void, **opts
    attach_function :zsock_set_linger,            [:pointer, :int], :void, **opts
    attach_function :zsock_set_ipv6,              [:pointer, :int], :void, **opts
    attach_function :zsock_set_reconnect_ivl,     [:pointer, :int], :void, **opts

    # -----------------------------------------------------------------
    # zmsg functions
    # -----------------------------------------------------------------
    attach_function :zmsg_new,          [], :pointer, **opts
    attach_function :zmsg_destroy,      [:pointer], :void, **opts
    attach_function :zmsg_send,         [:pointer, :pointer], :int, **opts
    attach_function :zmsg_recv,         [:pointer], :pointer, **opts
    attach_function :zmsg_addmem,       [:pointer, :pointer, :size_t], :int, **opts
    attach_function :zmsg_append,       [:pointer, :pointer], :int, **opts
    attach_function :zmsg_pushmem,      [:pointer, :pointer, :size_t], :int, **opts
    attach_function :zmsg_prepend,      [:pointer, :pointer], :int, **opts
    attach_function :zmsg_pop,          [:pointer], :pointer, **opts
    attach_function :zmsg_content_size, [:pointer], :size_t, **opts
    attach_function :zmsg_first,        [:pointer], :pointer, **opts
    attach_function :zmsg_next,         [:pointer], :pointer, **opts
    attach_function :zmsg_last,         [:pointer], :pointer, **opts
    attach_function :zmsg_size,         [:pointer], :size_t, **opts

    # -----------------------------------------------------------------
    # zframe functions
    # -----------------------------------------------------------------
    attach_function :zframe_new,         [:pointer, :size_t], :pointer, **opts
    attach_function :zframe_new_empty,   [], :pointer, **opts
    attach_function :zframe_destroy,     [:pointer], :void, **opts
    attach_function :zframe_send,        [:pointer, :pointer, :int], :int, **opts
    attach_function :zframe_recv,        [:pointer], :pointer, **opts
    attach_function :zframe_data,        [:pointer], :pointer, **opts
    attach_function :zframe_size,        [:pointer], :size_t, **opts
    attach_function :zframe_reset,       [:pointer, :pointer, :size_t], :void, **opts
    attach_function :zframe_dup,         [:pointer], :pointer, **opts
    attach_function :zframe_more,        [:pointer], :int, **opts
    attach_function :zframe_set_more,    [:pointer, :int], :void, **opts
    attach_function :zframe_eq,          [:pointer, :pointer], :bool, **opts

    # -----------------------------------------------------------------
    # zactor functions
    # -----------------------------------------------------------------
    attach_function :zactor_new,     [:pointer, :pointer], :pointer, **opts
    attach_function :zactor_destroy, [:pointer], :void, **opts

    # -----------------------------------------------------------------
    # zconfig functions
    # -----------------------------------------------------------------
    attach_function :zconfig_new,         [:string, :pointer], :pointer, **opts
    attach_function :zconfig_destroy,     [:pointer], :void, **opts
    attach_function :zconfig_load,        [:string], :pointer, **opts
    attach_function :zconfig_str_load,    [:string], :pointer, **opts
    attach_function :zconfig_name,        [:pointer], :pointer, **opts
    attach_function :zconfig_set_name,    [:pointer, :string], :void, **opts
    attach_function :zconfig_value,       [:pointer], :pointer, **opts
    attach_function :zconfig_set_value,   [:pointer, :string, :varargs], :void, **opts
    attach_function :zconfig_put,         [:pointer, :string, :string], :void, **opts
    attach_function :zconfig_get,         [:pointer, :string, :string], :pointer, **opts
    attach_function :zconfig_locate,      [:pointer, :string], :pointer, **opts
    attach_function :zconfig_at_depth,    [:pointer, :int], :pointer, **opts
    attach_function :zconfig_next,        [:pointer], :pointer, **opts
    attach_function :zconfig_child,       [:pointer], :pointer, **opts
    attach_function :zconfig_execute,     [:pointer, :pointer, :pointer], :int, **opts
    attach_function :zconfig_save,        [:pointer, :string], :int, **opts
    attach_function :zconfig_str_save,    [:pointer], :pointer, **opts
    attach_function :zconfig_filename,    [:pointer], :string, **opts
    attach_function :zconfig_comments,    [:pointer], :pointer, **opts
    attach_function :zconfig_set_comment, [:pointer, :string, :varargs], :void, **opts

    # -----------------------------------------------------------------
    # zcert functions
    # -----------------------------------------------------------------
    attach_function :zcert_new,            [], :pointer, **opts
    attach_function :zcert_destroy,        [:pointer], :void, **opts
    attach_function :zcert_load,           [:string], :pointer, **opts
    attach_function :zcert_new_from,       [:pointer, :pointer], :pointer, **opts
    attach_function :zcert_public_txt,     [:pointer], :string, **opts
    attach_function :zcert_public_key,     [:pointer], :pointer, **opts
    attach_function :zcert_secret_txt,     [:pointer], :string, **opts
    attach_function :zcert_secret_key,     [:pointer], :pointer, **opts
    attach_function :zcert_meta,           [:pointer, :string], :string, **opts
    attach_function :zcert_set_meta,       [:pointer, :string, :string, :varargs], :void, **opts
    attach_function :zcert_meta_keys,      [:pointer], :pointer, **opts
    attach_function :zcert_save,           [:pointer, :string], :int, **opts
    attach_function :zcert_save_public,    [:pointer, :string], :int, **opts
    attach_function :zcert_save_secret,    [:pointer, :string], :int, **opts
    attach_function :zcert_apply,          [:pointer, :pointer], :void, **opts
    attach_function :zcert_dup,            [:pointer], :pointer, **opts
    attach_function :zcert_eq,             [:pointer, :pointer], :bool, **opts

    begin
      attach_function :zcert_unset_meta,   [:pointer, :string], :void, **opts
    rescue ::FFI::NotFoundError; end

    # -----------------------------------------------------------------
    # zcertstore functions
    # -----------------------------------------------------------------
    attach_function :zcertstore_new,     [:string], :pointer, **opts
    attach_function :zcertstore_destroy, [:pointer], :void, **opts
    attach_function :zcertstore_lookup,  [:pointer, :string], :pointer, **opts
    attach_function :zcertstore_insert,  [:pointer, :pointer], :void, **opts

    # -----------------------------------------------------------------
    # zarmour functions
    # -----------------------------------------------------------------
    attach_function :zarmour_new,      [], :pointer, **opts
    attach_function :zarmour_destroy,  [:pointer], :void, **opts
    attach_function :zarmour_set_mode, [:pointer, :int], :void, **opts
    attach_function :zarmour_encode,   [:pointer, :pointer, :size_t], :pointer, **opts
    attach_function :zarmour_decode,   [:pointer, :string], :pointer, **opts

    # -----------------------------------------------------------------
    # zchunk functions (minimal, for zarmour decode result)
    # -----------------------------------------------------------------
    attach_function :zchunk_destroy,   [:pointer], :void, **opts
    attach_function :zchunk_data,      [:pointer], :pointer, **opts
    attach_function :zchunk_size,      [:pointer], :size_t, **opts

    # -----------------------------------------------------------------
    # zstr functions
    # -----------------------------------------------------------------
    attach_function :zstr_recv,  [:pointer], :pointer, **opts

    # -----------------------------------------------------------------
    # zlist functions (minimal, for zcert meta_keys and zconfig comments)
    # -----------------------------------------------------------------
    attach_function :zlist_first, [:pointer], :pointer, **opts
    attach_function :zlist_next,  [:pointer], :pointer, **opts
    attach_function :zlist_size,  [:pointer], :size_t, **opts

    # =================================================================
    # Wrapper Classes
    # =================================================================

    # Base module for common wrapper logic.
    module Wrapper
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def prevent_leak(ptr, destroy_fn)
          prevent_leak_ptr = ::FFI::MemoryPointer.new(:pointer)
          prevent_leak_ptr.write_pointer(ptr)
          prevent_leak_fn = destroy_fn
          ->(id) { CZMQ::FFI.__send__(prevent_leak_fn, prevent_leak_ptr) }
        end
      end

      def to_ptr
        raise DestroyedError if @moved
        @ptr
      end

      def null?
        @ptr.null? || @moved
      end

      def __undef_finalizer
        ObjectSpace.undefine_finalizer(self)
        @finalizer = nil
        self
      end

      # Give away ownership of the pointer (e.g. for zmsg_send which
      # takes a pointer-to-pointer and nullifies it).
      def __ptr_give_ref
        raise DestroyedError if @moved
        ptr_ptr = ::FFI::MemoryPointer.new(:pointer)
        ptr_ptr.write_pointer(@ptr)
        @moved = true
        ObjectSpace.undefine_finalizer(self)
        ptr_ptr
      end
    end

    # Raised when trying to use a wrapper whose native object has been
    # destroyed or ownership has been transferred.
    class DestroyedError < RuntimeError; end

    # -----------------------------------------------------------------
    # Errors
    # -----------------------------------------------------------------
    module Errors
      def self.errno
        CZMQ::FFI.zmq_errno
      end

      def self.strerror
        CZMQ::FFI.zmq_strerror(CZMQ::FFI.zmq_errno)
      end
    end

    # -----------------------------------------------------------------
    # Signals
    # -----------------------------------------------------------------
    module Signals
      def self.disable_default_handling
        CZMQ::FFI.zsys_handler_set(nil)
        @default_handling_disabled = true
      end

      def self.default_handling_disabled?
        @default_handling_disabled || false
      end
    end

    # -----------------------------------------------------------------
    # Zsys
    # -----------------------------------------------------------------
    module Zsys
      def self.has_curve
        CZMQ::FFI.zsys_has_curve
      end

      def self.set_logstream(stream)
        CZMQ::FFI.zsys_set_logstream(stream)
      end
    end

    # Version constants (determined at runtime from the loaded libraries)
    zmq_maj = ::FFI::MemoryPointer.new(:int)
    zmq_min = ::FFI::MemoryPointer.new(:int)
    zmq_pat = ::FFI::MemoryPointer.new(:int)
    zmq_version(zmq_maj, zmq_min, zmq_pat)
    ZMQ_VERSION = "#{zmq_maj.read_int}.#{zmq_min.read_int}.#{zmq_pat.read_int}".freeze

    czmq_maj = ::FFI::MemoryPointer.new(:int)
    czmq_min = ::FFI::MemoryPointer.new(:int)
    czmq_pat = ::FFI::MemoryPointer.new(:int)
    zsys_version(czmq_maj, czmq_min, czmq_pat)
    CZMQ_VERSION = "#{czmq_maj.read_int}.#{czmq_min.read_int}.#{czmq_pat.read_int}".freeze

    # -----------------------------------------------------------------
    # Zsock
    # -----------------------------------------------------------------
    class Zsock
      include Wrapper

      DestroyedError = CZMQ::FFI::DestroyedError

      def initialize(ptr_or_type, owned = true)
        if ptr_or_type.is_a?(::FFI::Pointer)
          @ptr = ptr_or_type
        else
          @ptr = CZMQ::FFI.zsock_new(ptr_or_type)
        end
        @moved = false
        if owned && !@ptr.null?
          ObjectSpace.define_finalizer(self,
            self.class.prevent_leak(@ptr, :zsock_destroy))
        end
      end

      # Factory methods
      def self.new_req(endpoint)     = _wrap(CZMQ::FFI.zsock_new_req(endpoint))
      def self.new_rep(endpoint)     = _wrap(CZMQ::FFI.zsock_new_rep(endpoint))
      def self.new_dealer(endpoint)  = _wrap(CZMQ::FFI.zsock_new_dealer(endpoint))
      def self.new_router(endpoint)  = _wrap(CZMQ::FFI.zsock_new_router(endpoint))
      def self.new_pub(endpoint)     = _wrap(CZMQ::FFI.zsock_new_pub(endpoint))
      def self.new_sub(endpoint, subscribe) = _wrap(CZMQ::FFI.zsock_new_sub(endpoint, subscribe))
      def self.new_xpub(endpoint)    = _wrap(CZMQ::FFI.zsock_new_xpub(endpoint))
      def self.new_xsub(endpoint)    = _wrap(CZMQ::FFI.zsock_new_xsub(endpoint))
      def self.new_push(endpoint)    = _wrap(CZMQ::FFI.zsock_new_push(endpoint))
      def self.new_pull(endpoint)    = _wrap(CZMQ::FFI.zsock_new_pull(endpoint))
      def self.new_pair(endpoint)    = _wrap(CZMQ::FFI.zsock_new_pair(endpoint))
      def self.new_stream(endpoint)  = _wrap(CZMQ::FFI.zsock_new_stream(endpoint))

      def self._wrap(ptr)
        obj = allocate
        obj.instance_variable_set(:@ptr, ptr)
        obj.instance_variable_set(:@moved, false)
        unless ptr.null?
          ObjectSpace.define_finalizer(obj,
            prevent_leak(ptr, :zsock_destroy))
        end
        obj
      end
      private_class_method :_wrap

      # Instance methods
      def endpoint
        CZMQ::FFI.zsock_endpoint(@ptr)
      end

      def connect(format, *args)
        CZMQ::FFI.zsock_connect(@ptr, format, *args)
      end

      def disconnect(format, *args)
        CZMQ::FFI.zsock_disconnect(@ptr, format, *args)
      end

      def bind(format, *args)
        CZMQ::FFI.zsock_bind(@ptr, format, *args)
      end

      def unbind(format, *args)
        CZMQ::FFI.zsock_unbind(@ptr, format, *args)
      end

      def destroy
        return if @moved
        ptr_ptr = ::FFI::MemoryPointer.new(:pointer)
        ptr_ptr.write_pointer(@ptr)
        CZMQ::FFI.zsock_destroy(ptr_ptr)
        @moved = true
        ObjectSpace.undefine_finalizer(self)
      end

      def set_subscribe(prefix)
        CZMQ::FFI.zsock_set_subscribe(@ptr, prefix)
      end

      def set_unsubscribe(prefix)
        CZMQ::FFI.zsock_set_unsubscribe(@ptr, prefix)
      end

      # Class methods that take a zsock pointer (or wrapper with to_ptr)
      # These are called as Zsock.method_name(zocket, ...) from zsock_options.rb

      def self._resolve_ptr(zocket)
        zocket.respond_to?(:to_ptr) ? zocket.to_ptr : zocket
      end
      private_class_method :_resolve_ptr

      def self.resolve(zocket)
        CZMQ::FFI.zsock_resolve(_resolve_ptr(zocket))
      end

      def self.signal(zocket, status)
        CZMQ::FFI.zsock_signal(_resolve_ptr(zocket), status)
      end

      def self.wait(zocket)
        CZMQ::FFI.zsock_wait(_resolve_ptr(zocket))
      end

      def self.set_unbounded(zocket)
        CZMQ::FFI.zsock_set_unbounded(_resolve_ptr(zocket))
      end

      # Override Object#send to call zsock_send.
      # Called as: CZMQ::FFI::Zsock.send(delegate, picture, *args)
      def self.send(zocket, picture, *args)
        CZMQ::FFI.zsock_send_picture(_resolve_ptr(zocket), picture, *args)
      end

      # Option getters (class methods taking a zocket)
      def self.sndhwm(zocket)           = CZMQ::FFI.zsock_sndhwm(_resolve_ptr(zocket))
      def self.rcvhwm(zocket)           = CZMQ::FFI.zsock_rcvhwm(_resolve_ptr(zocket))
      def self.mechanism(zocket)        = CZMQ::FFI.zsock_mechanism(_resolve_ptr(zocket))
      def self.curve_server(zocket)     = CZMQ::FFI.zsock_curve_server(_resolve_ptr(zocket))
      def self.curve_serverkey(zocket)  = CZMQ::FFI.zsock_curve_serverkey(_resolve_ptr(zocket))
      def self.curve_secretkey(zocket)  = CZMQ::FFI.zsock_curve_secretkey(_resolve_ptr(zocket))
      def self.curve_publickey(zocket)  = CZMQ::FFI.zsock_curve_publickey(_resolve_ptr(zocket))
      def self.zap_domain(zocket)       = CZMQ::FFI.zsock_zap_domain(_resolve_ptr(zocket))
      def self.plain_server(zocket)     = CZMQ::FFI.zsock_plain_server(_resolve_ptr(zocket))
      def self.plain_username(zocket)   = CZMQ::FFI.zsock_plain_username(_resolve_ptr(zocket))
      def self.plain_password(zocket)   = CZMQ::FFI.zsock_plain_password(_resolve_ptr(zocket))
      def self.rcvtimeo(zocket)         = CZMQ::FFI.zsock_rcvtimeo(_resolve_ptr(zocket))
      def self.sndtimeo(zocket)         = CZMQ::FFI.zsock_sndtimeo(_resolve_ptr(zocket))
      def self.identity(zocket)         = CZMQ::FFI.zsock_identity(_resolve_ptr(zocket))
      def self.tos(zocket)              = CZMQ::FFI.zsock_tos(_resolve_ptr(zocket))
      def self.heartbeat_ivl(zocket)    = CZMQ::FFI.zsock_heartbeat_ivl(_resolve_ptr(zocket))
      def self.heartbeat_ttl(zocket)    = CZMQ::FFI.zsock_heartbeat_ttl(_resolve_ptr(zocket))
      def self.heartbeat_timeout(zocket) = CZMQ::FFI.zsock_heartbeat_timeout(_resolve_ptr(zocket))
      def self.linger(zocket)           = CZMQ::FFI.zsock_linger(_resolve_ptr(zocket))
      def self.ipv6(zocket)             = CZMQ::FFI.zsock_ipv6(_resolve_ptr(zocket))
      def self.fd(zocket)               = CZMQ::FFI.zsock_fd(_resolve_ptr(zocket))
      def self.events(zocket)           = CZMQ::FFI.zsock_events(_resolve_ptr(zocket))
      def self.reconnect_ivl(zocket)    = CZMQ::FFI.zsock_reconnect_ivl(_resolve_ptr(zocket))

      # Option setters (class methods taking a zocket)
      def self.set_sndhwm(zocket, val)           = CZMQ::FFI.zsock_set_sndhwm(_resolve_ptr(zocket), val)
      def self.set_rcvhwm(zocket, val)           = CZMQ::FFI.zsock_set_rcvhwm(_resolve_ptr(zocket), val)
      def self.set_curve_server(zocket, val)     = CZMQ::FFI.zsock_set_curve_server(_resolve_ptr(zocket), val)
      def self.set_curve_serverkey(zocket, val)  = CZMQ::FFI.zsock_set_curve_serverkey(_resolve_ptr(zocket), val)
      def self.set_curve_serverkey_bin(zocket, val) = CZMQ::FFI.zsock_set_curve_serverkey_bin(_resolve_ptr(zocket), val)
      def self.set_zap_domain(zocket, val)       = CZMQ::FFI.zsock_set_zap_domain(_resolve_ptr(zocket), val)
      def self.set_plain_server(zocket, val)     = CZMQ::FFI.zsock_set_plain_server(_resolve_ptr(zocket), val)
      def self.set_plain_username(zocket, val)   = CZMQ::FFI.zsock_set_plain_username(_resolve_ptr(zocket), val)
      def self.set_plain_password(zocket, val)   = CZMQ::FFI.zsock_set_plain_password(_resolve_ptr(zocket), val)
      def self.set_rcvtimeo(zocket, val)         = CZMQ::FFI.zsock_set_rcvtimeo(_resolve_ptr(zocket), val)
      def self.set_sndtimeo(zocket, val)         = CZMQ::FFI.zsock_set_sndtimeo(_resolve_ptr(zocket), val)
      def self.set_router_mandatory(zocket, val) = CZMQ::FFI.zsock_set_router_mandatory(_resolve_ptr(zocket), val)
      def self.set_identity(zocket, val)         = CZMQ::FFI.zsock_set_identity(_resolve_ptr(zocket), val)
      def self.set_tos(zocket, val)              = CZMQ::FFI.zsock_set_tos(_resolve_ptr(zocket), val)
      def self.set_heartbeat_ivl(zocket, val)    = CZMQ::FFI.zsock_set_heartbeat_ivl(_resolve_ptr(zocket), val)
      def self.set_heartbeat_ttl(zocket, val)    = CZMQ::FFI.zsock_set_heartbeat_ttl(_resolve_ptr(zocket), val)
      def self.set_heartbeat_timeout(zocket, val) = CZMQ::FFI.zsock_set_heartbeat_timeout(_resolve_ptr(zocket), val)
      def self.set_linger(zocket, val)           = CZMQ::FFI.zsock_set_linger(_resolve_ptr(zocket), val)
      def self.set_ipv6(zocket, val)             = CZMQ::FFI.zsock_set_ipv6(_resolve_ptr(zocket), val)
      def self.set_reconnect_ivl(zocket, val)    = CZMQ::FFI.zsock_set_reconnect_ivl(_resolve_ptr(zocket), val)
    end

    # -----------------------------------------------------------------
    # Zmsg
    # -----------------------------------------------------------------
    class Zmsg
      include Wrapper

      DestroyedError = CZMQ::FFI::DestroyedError

      def initialize(ptr = nil, owned = true)
        if ptr.is_a?(::FFI::Pointer)
          @ptr = ptr
        else
          @ptr = CZMQ::FFI.zmsg_new
        end
        @moved = false
        if owned && !@ptr.null?
          ObjectSpace.define_finalizer(self,
            self.class.prevent_leak(@ptr, :zmsg_destroy))
        end
      end

      def self._wrap(ptr, owned = true)
        obj = allocate
        obj.instance_variable_set(:@ptr, ptr)
        obj.instance_variable_set(:@moved, false)
        if owned && !ptr.null?
          ObjectSpace.define_finalizer(obj,
            prevent_leak(ptr, :zmsg_destroy))
        end
        obj
      end
      private_class_method :_wrap

      # Override Object#send: int zmsg_send(zmsg_t **self_p, void *dest)
      # Called as: Zmsg.send(zmsg_wrapper_or_ptr, destination)
      def self.send(msg, dest)
        msg_ptr = msg.respond_to?(:__ptr_give_ref) ? msg.__ptr_give_ref : msg
        dest_ptr = dest.respond_to?(:to_ptr) ? dest.to_ptr : dest
        CZMQ::FFI.zmsg_send(msg_ptr, dest_ptr)
      end

      def self.recv(source)
        source_ptr = source.respond_to?(:to_ptr) ? source.to_ptr : source
        ptr = CZMQ::FFI.zmsg_recv(source_ptr)
        _wrap(ptr)
      end

      def addmem(data, size)
        CZMQ::FFI.zmsg_addmem(@ptr, data, size)
      end

      def append(frame)
        frame_ptr = frame.respond_to?(:__ptr_give_ref) ? frame.__ptr_give_ref : frame
        CZMQ::FFI.zmsg_append(@ptr, frame_ptr)
      end

      def pushmem(data, size)
        CZMQ::FFI.zmsg_pushmem(@ptr, data, size)
      end

      def prepend(frame)
        frame_ptr = frame.respond_to?(:__ptr_give_ref) ? frame.__ptr_give_ref : frame
        CZMQ::FFI.zmsg_prepend(@ptr, frame_ptr)
      end

      def pop
        ptr = CZMQ::FFI.zmsg_pop(@ptr)
        Zframe._from_ptr(ptr)
      end

      def content_size
        CZMQ::FFI.zmsg_content_size(@ptr)
      end

      def first
        ptr = CZMQ::FFI.zmsg_first(@ptr)
        _borrowed_frame(ptr)
      end

      def next
        ptr = CZMQ::FFI.zmsg_next(@ptr)
        _borrowed_frame(ptr)
      end

      def last
        ptr = CZMQ::FFI.zmsg_last(@ptr)
        _borrowed_frame(ptr)
      end

      def size
        CZMQ::FFI.zmsg_size(@ptr)
      end

      private

      # Returns a Zframe that does NOT own the pointer (borrowed from zmsg).
      def _borrowed_frame(ptr)
        Zframe._from_ptr(ptr, false)
      end
    end

    # -----------------------------------------------------------------
    # Zframe
    # -----------------------------------------------------------------
    class Zframe
      include Wrapper

      DestroyedError = CZMQ::FFI::DestroyedError

      def initialize(data = nil, size = nil)
        if data.is_a?(::FFI::Pointer) && !size.nil?
          # new(ptr, size) — creating from data pointer and size
          @ptr = CZMQ::FFI.zframe_new(data, size)
        elsif data.is_a?(::FFI::Pointer)
          # wrapping an existing zframe_t* pointer
          @ptr = data
        elsif data.nil?
          @ptr = CZMQ::FFI.zframe_new_empty
        else
          mem = ::FFI::MemoryPointer.from_string(data.to_s)
          @ptr = CZMQ::FFI.zframe_new(mem, data.to_s.bytesize)
        end
        @moved = false
        ObjectSpace.define_finalizer(self,
          self.class.prevent_leak(@ptr, :zframe_destroy)) unless @ptr.null?
      end

      def self.new_empty
        _from_ptr(CZMQ::FFI.zframe_new_empty)
      end

      # Used internally to wrap a raw pointer.
      # @param ptr [FFI::Pointer] zframe_t pointer
      # @param owned [Boolean] whether we own this pointer
      def self._from_ptr(ptr, owned = true)
        obj = allocate
        obj.instance_variable_set(:@ptr, ptr)
        obj.instance_variable_set(:@moved, false)
        if owned && !ptr.null?
          ObjectSpace.define_finalizer(obj,
            prevent_leak(ptr, :zframe_destroy))
        end
        obj
      end

      # Public alias used by Frame after send to re-wrap a pointer.
      def self.__new(ptr, owned)
        _from_ptr(ptr, owned)
      end

      # Override Object#send: int zframe_send(zframe_t **self_p, void *dest, int flags)
      def self.send(frame, dest, flags)
        frame_ptr = frame.respond_to?(:__ptr_give_ref) ? frame.__ptr_give_ref : frame
        dest_ptr = dest.respond_to?(:to_ptr) ? dest.to_ptr : dest
        CZMQ::FFI.zframe_send(frame_ptr, dest_ptr, flags)
      end

      def self.recv(source)
        source_ptr = source.respond_to?(:to_ptr) ? source.to_ptr : source
        ptr = CZMQ::FFI.zframe_recv(source_ptr)
        _from_ptr(ptr)
      end

      def data
        CZMQ::FFI.zframe_data(@ptr)
      end

      def size
        CZMQ::FFI.zframe_size(@ptr)
      end

      def reset(data, size)
        CZMQ::FFI.zframe_reset(@ptr, data, size)
      end

      def dup
        ptr = CZMQ::FFI.zframe_dup(@ptr)
        self.class._from_ptr(ptr)
      end

      def more
        CZMQ::FFI.zframe_more(@ptr)
      end

      def set_more(val)
        CZMQ::FFI.zframe_set_more(@ptr, val)
      end

      def eq(other)
        other_ptr = other.respond_to?(:to_ptr) ? other.to_ptr : other
        CZMQ::FFI.zframe_eq(@ptr, other_ptr)
      end

    end

    # -----------------------------------------------------------------
    # Zactor
    # -----------------------------------------------------------------
    class Zactor
      include Wrapper

      DestroyedError = CZMQ::FFI::DestroyedError

      # @param callback [FFI::Pointer, FFI::Function] callback function pointer
      # @param args [FFI::Pointer, nil] arguments pointer
      def initialize(callback, args = nil)
        args = args.respond_to?(:to_ptr) ? args.to_ptr : (args || ::FFI::Pointer::NULL)
        callback_ptr = callback.is_a?(::FFI::Pointer) ? callback : callback
        @ptr = CZMQ::FFI.zactor_new(callback_ptr, args)
        @moved = false
        unless @ptr.null?
          ObjectSpace.define_finalizer(self,
            self.class.prevent_leak(@ptr, :zactor_destroy))
        end
      end

      def destroy
        return if @moved
        ptr_ptr = ::FFI::MemoryPointer.new(:pointer)
        ptr_ptr.write_pointer(@ptr)
        CZMQ::FFI.zactor_destroy(ptr_ptr)
        @moved = true
        ObjectSpace.undefine_finalizer(self)
      end

      # Creates an FFI::Function callback with the zactor handler signature:
      #   void (*)(zsock_t *pipe, void *args)
      def self.fn(&block)
        ::FFI::Function.new(:void, [:pointer, :pointer]) do |pipe, args|
          # Wrap pipe as a Zsock that does NOT own the pointer
          pipe_delegate = Zsock._wrap_borrowed(pipe)
          block.call(pipe_delegate, args)
        end
      end
    end

    # Extend Zsock with a borrowed-pointer wrapper for Zactor pipe
    class Zsock
      # Wraps a pointer without taking ownership (no finalizer).
      def self._wrap_borrowed(ptr)
        obj = allocate
        obj.instance_variable_set(:@ptr, ptr)
        obj.instance_variable_set(:@moved, false)
        obj
      end
    end

    # -----------------------------------------------------------------
    # Zconfig
    # -----------------------------------------------------------------
    class Zconfig
      include Wrapper

      DestroyedError = CZMQ::FFI::DestroyedError

      def initialize(name, parent)
        parent_ptr = parent.respond_to?(:to_ptr) ? parent.to_ptr : (parent || ::FFI::Pointer::NULL)
        @ptr = CZMQ::FFI.zconfig_new(name, parent_ptr)
        @moved = false
        unless @ptr.null?
          @finalizer = self.class.prevent_leak(@ptr, :zconfig_destroy)
          ObjectSpace.define_finalizer(self, @finalizer)
        end
      end

      def self._wrap(ptr, owned = true)
        obj = allocate
        obj.instance_variable_set(:@ptr, ptr)
        obj.instance_variable_set(:@moved, false)
        if owned && !ptr.null?
          finalizer = prevent_leak(ptr, :zconfig_destroy)
          obj.instance_variable_set(:@finalizer, finalizer)
          ObjectSpace.define_finalizer(obj, finalizer)
        end
        obj
      end
      private_class_method :_wrap

      def self.load(filename)
        ptr = CZMQ::FFI.zconfig_load(filename)
        _wrap(ptr)
      end

      def self.str_load(string)
        ptr = CZMQ::FFI.zconfig_str_load(string)
        _wrap(ptr)
      end

      # Creates an FFI::Function callback for zconfig_execute:
      #   int (*handler)(zconfig_t *self, void *arg, int level)
      def self.fct(&block)
        ::FFI::Function.new(:int, [:pointer, :pointer, :int]) do |zconfig_ptr, arg, level|
          # Wrap as a Zconfig that does NOT own the pointer
          zconfig = _wrap(zconfig_ptr, false)
          block.call(zconfig, arg, level)
        end
      end

      def name
        CZMQ::FFI.zconfig_name(@ptr)
      end

      def set_name(name)
        CZMQ::FFI.zconfig_set_name(@ptr, name)
      end

      def value
        CZMQ::FFI.zconfig_value(@ptr)
      end

      def set_value(format, *args)
        CZMQ::FFI.zconfig_set_value(@ptr, format, *args)
      end

      def put(path, value)
        CZMQ::FFI.zconfig_put(@ptr, path, value)
      end

      def get(path, default)
        CZMQ::FFI.zconfig_get(@ptr, path, default)
      end

      def locate(path)
        ptr = CZMQ::FFI.zconfig_locate(@ptr, path)
        self.class.__send__(:_wrap, ptr, false)
      end

      def at_depth(level)
        ptr = CZMQ::FFI.zconfig_at_depth(@ptr, level)
        self.class.__send__(:_wrap, ptr, false)
      end

      def next
        ptr = CZMQ::FFI.zconfig_next(@ptr)
        self.class.__send__(:_wrap, ptr, false)
      end

      def child
        ptr = CZMQ::FFI.zconfig_child(@ptr)
        self.class.__send__(:_wrap, ptr, false)
      end

      def execute(handler, arg)
        arg_ptr = arg.respond_to?(:to_ptr) ? arg.to_ptr : (arg || ::FFI::Pointer::NULL)
        CZMQ::FFI.zconfig_execute(@ptr, handler, arg_ptr)
      end

      def save(filename)
        CZMQ::FFI.zconfig_save(@ptr, filename)
      end

      def str_save
        CZMQ::FFI.zconfig_str_save(@ptr)
      end

      def filename
        CZMQ::FFI.zconfig_filename(@ptr)
      end

      def comments
        ptr = CZMQ::FFI.zconfig_comments(@ptr)
        Zlist._wrap(ptr)
      end

      def set_comment(format, *args)
        if format.nil?
          CZMQ::FFI.zconfig_set_comment(@ptr, nil)
        else
          CZMQ::FFI.zconfig_set_comment(@ptr, format, *args)
        end
      end

      def destroy
        return if @moved
        ptr_ptr = ::FFI::MemoryPointer.new(:pointer)
        ptr_ptr.write_pointer(@ptr)
        CZMQ::FFI.zconfig_destroy(ptr_ptr)
        @moved = true
        ObjectSpace.undefine_finalizer(self)
      end
    end

    # -----------------------------------------------------------------
    # Zcert
    # -----------------------------------------------------------------
    class Zcert
      include Wrapper

      DestroyedError = CZMQ::FFI::DestroyedError

      def initialize(ptr = nil)
        if ptr.is_a?(::FFI::Pointer)
          @ptr = ptr
        else
          @ptr = CZMQ::FFI.zcert_new
        end
        @moved = false
        unless @ptr.null?
          ObjectSpace.define_finalizer(self,
            self.class.prevent_leak(@ptr, :zcert_destroy))
        end
      end

      def self._wrap(ptr, owned = true)
        obj = allocate
        obj.instance_variable_set(:@ptr, ptr)
        obj.instance_variable_set(:@moved, false)
        if owned && !ptr.null?
          ObjectSpace.define_finalizer(obj,
            prevent_leak(ptr, :zcert_destroy))
        end
        obj
      end
      private_class_method :_wrap

      def self.load(filename)
        ptr = CZMQ::FFI.zcert_load(filename)
        _wrap(ptr)
      end

      def self.new_from(public_key, secret_key)
        pub_ptr = public_key.is_a?(::FFI::Pointer) ? public_key : ::FFI::MemoryPointer.from_string(public_key)
        sec_ptr = secret_key.is_a?(::FFI::Pointer) ? secret_key : ::FFI::MemoryPointer.from_string(secret_key)
        ptr = CZMQ::FFI.zcert_new_from(pub_ptr, sec_ptr)
        _wrap(ptr)
      end

      def public_txt
        CZMQ::FFI.zcert_public_txt(@ptr)
      end

      def public_key
        CZMQ::FFI.zcert_public_key(@ptr)
      end

      def secret_txt
        CZMQ::FFI.zcert_secret_txt(@ptr)
      end

      def secret_key
        CZMQ::FFI.zcert_secret_key(@ptr)
      end

      def meta(name)
        CZMQ::FFI.zcert_meta(@ptr, name)
      end

      def set_meta(name, format, *args)
        CZMQ::FFI.zcert_set_meta(@ptr, name, format, *args)
      end

      def unset_meta(name)
        CZMQ::FFI.zcert_unset_meta(@ptr, name)
      rescue NoMethodError
        raise NotImplementedError, 'unset_meta requires DRAFT API'
      end

      def meta_keys
        ptr = CZMQ::FFI.zcert_meta_keys(@ptr)
        Zlist._wrap(ptr)
      end

      def save(filename)
        CZMQ::FFI.zcert_save(@ptr, filename)
      end

      def save_public(filename)
        CZMQ::FFI.zcert_save_public(@ptr, filename)
      end

      def save_secret(filename)
        CZMQ::FFI.zcert_save_secret(@ptr, filename)
      end

      def apply(zocket)
        zocket_ptr = zocket.respond_to?(:to_ptr) ? zocket.to_ptr : zocket
        CZMQ::FFI.zcert_apply(@ptr, zocket_ptr)
      end

      def dup
        ptr = CZMQ::FFI.zcert_dup(@ptr)
        self.class.__send__(:_wrap, ptr)
      end

      def eq(other)
        other_ptr = other.respond_to?(:to_ptr) ? other.to_ptr : other
        CZMQ::FFI.zcert_eq(@ptr, other_ptr)
      end
    end

    # -----------------------------------------------------------------
    # Zcertstore
    # -----------------------------------------------------------------
    class Zcertstore
      include Wrapper

      DestroyedError = CZMQ::FFI::DestroyedError

      def initialize(location)
        @ptr = CZMQ::FFI.zcertstore_new(location)
        @moved = false
        unless @ptr.null?
          ObjectSpace.define_finalizer(self,
            self.class.prevent_leak(@ptr, :zcertstore_destroy))
        end
      end

      def lookup(pubkey)
        ptr = CZMQ::FFI.zcertstore_lookup(@ptr, pubkey)
        # Returns a Zcert that does NOT own the pointer (store owns it)
        Zcert.__send__(:_wrap, ptr, false)
      end

      def insert(cert)
        # zcertstore_insert takes ownership; give away the pointer
        cert_ptr = cert.respond_to?(:__ptr_give_ref) ? cert.__ptr_give_ref : cert
        CZMQ::FFI.zcertstore_insert(@ptr, cert_ptr)
      end
    end

    # -----------------------------------------------------------------
    # Zarmour
    # -----------------------------------------------------------------
    class Zarmour
      include Wrapper

      DestroyedError = CZMQ::FFI::DestroyedError

      MODE_Z85 = 5

      def initialize
        @ptr = CZMQ::FFI.zarmour_new
        @moved = false
        unless @ptr.null?
          ObjectSpace.define_finalizer(self,
            self.class.prevent_leak(@ptr, :zarmour_destroy))
        end
      end

      def set_mode(mode)
        CZMQ::FFI.zarmour_set_mode(@ptr, mode)
      end

      def encode(data, size)
        CZMQ::FFI.zarmour_encode(@ptr, data, size)
      end

      def decode(string)
        ptr = CZMQ::FFI.zarmour_decode(@ptr, string)
        Zchunk._wrap(ptr)
      end
    end

    # -----------------------------------------------------------------
    # Zchunk (minimal wrapper for zarmour decode results)
    # -----------------------------------------------------------------
    class Zchunk
      include Wrapper

      DestroyedError = CZMQ::FFI::DestroyedError

      def self._wrap(ptr)
        obj = allocate
        obj.instance_variable_set(:@ptr, ptr)
        obj.instance_variable_set(:@moved, false)
        unless ptr.null?
          ObjectSpace.define_finalizer(obj,
            prevent_leak(ptr, :zchunk_destroy))
        end
        obj
      end

      def data
        CZMQ::FFI.zchunk_data(@ptr)
      end

      def size
        CZMQ::FFI.zchunk_size(@ptr)
      end
    end

    # -----------------------------------------------------------------
    # Zstr
    # -----------------------------------------------------------------
    module Zstr
      def self.recv(source)
        source_ptr = source.respond_to?(:to_ptr) ? source.to_ptr : source
        CZMQ::FFI.zstr_recv(source_ptr)
      end
    end

    # -----------------------------------------------------------------
    # Zlist (minimal wrapper for iterating zlists returned by CZMQ)
    # -----------------------------------------------------------------
    class Zlist
      DestroyedError = CZMQ::FFI::DestroyedError

      def self._wrap(ptr)
        obj = allocate
        obj.instance_variable_set(:@ptr, ptr)
        obj
      end

      def null?
        @ptr.nil? || @ptr.null?
      end

      def first
        raise DestroyedError if null?
        CZMQ::FFI.zlist_first(@ptr)
      end

      def next
        raise DestroyedError if null?
        CZMQ::FFI.zlist_next(@ptr)
      end

      def size
        raise DestroyedError if null?
        CZMQ::FFI.zlist_size(@ptr)
      end
    end

  end

  # Disable CZMQ's default signal handlers so Ruby's own signal handling
  # (e.g. Ctrl-C) works correctly.
  FFI::Signals.disable_default_handling
end
