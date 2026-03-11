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
    attach_function :zsock_set_unbounded,  [:pointer], :void, **opts

    attach_function :zsock_set_subscribe,   [:pointer, :string], :void, **opts
    attach_function :zsock_set_unsubscribe, [:pointer, :string], :void, **opts

    # zsock option getters
    attach_function :zsock_sndhwm,           [:pointer], :int, **opts
    attach_function :zsock_rcvhwm,           [:pointer], :int, **opts
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
    attach_function :zmsg_addmem_s, 'zmsg_addmem', [:pointer, :buffer_in, :size_t], :int, **opts
    attach_function :zmsg_first,        [:pointer], :pointer, **opts
    attach_function :zmsg_next,         [:pointer], :pointer, **opts

    # -----------------------------------------------------------------
    # zframe functions
    # -----------------------------------------------------------------
    attach_function :zframe_destroy,     [:pointer], :void, **opts
    attach_function :zframe_data,        [:pointer], :pointer, **opts
    attach_function :zframe_size,        [:pointer], :size_t, **opts

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

      def self.strerror(errno = CZMQ::FFI.zmq_errno)
        CZMQ::FFI.zmq_strerror(errno)
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

      def self.set_unbounded(zocket)
        CZMQ::FFI.zsock_set_unbounded(_resolve_ptr(zocket))
      end

      # Option getters (class methods taking a zocket)
      def self.sndhwm(zocket)           = CZMQ::FFI.zsock_sndhwm(_resolve_ptr(zocket))
      def self.rcvhwm(zocket)           = CZMQ::FFI.zsock_rcvhwm(_resolve_ptr(zocket))
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

      # Appends a Ruby string directly without intermediate MemoryPointer copy.
      # Uses :buffer_in to pass the string's internal buffer pointer to C.
      def add_buffer(str)
        CZMQ::FFI.zmsg_addmem_s(@ptr, str, str.bytesize)
      end

      def first
        ptr = CZMQ::FFI.zmsg_first(@ptr)
        return nil if ptr.null?
        _borrowed_frame(ptr)
      end

      def next
        ptr = CZMQ::FFI.zmsg_next(@ptr)
        return nil if ptr.null?
        _borrowed_frame(ptr)
      end

      private

      # Returns a Zframe that does NOT own the pointer (borrowed from zmsg).
      def _borrowed_frame(ptr)
        Zframe._from_ptr(ptr, false)
      end
    end

    # -----------------------------------------------------------------
    # Zframe (lightweight — only used for borrowed frames from Zmsg)
    # -----------------------------------------------------------------
    class Zframe
      include Wrapper

      DestroyedError = CZMQ::FFI::DestroyedError

      # Used internally to wrap a raw pointer.
      # @param ptr [FFI::Pointer] zframe_t pointer
      # @param owned [Boolean] whether we own this pointer
      #
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

      def data
        CZMQ::FFI.zframe_data(@ptr)
      end

      def size
        CZMQ::FFI.zframe_size(@ptr)
      end
    end

  end

  # Disable CZMQ's default signal handlers so Ruby's own signal handling
  # (e.g. Ctrl-C) works correctly.
  FFI::Signals.disable_default_handling
end
