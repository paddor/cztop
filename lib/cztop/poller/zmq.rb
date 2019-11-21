module CZTop

  # CZTop's interface to the low-level +zmq_poller_*()+ functions.
  module Poller::ZMQ

    POLLIN  = 1
    POLLOUT = 2
    POLLERR = 4

    extend ::FFI::Library
    lib_name = 'libzmq'
    lib_dirs = ['/usr/local/lib', '/opt/local/lib', '/usr/lib64']
    lib_dirs = [*ENV['LIBZMQ_PATH'].split(':'), *lib_dirs] if ENV['LIBZMQ_PATH']
    lib_paths = lib_dirs.map { |path| "#{path}/#{lib_name}.#{::FFI::Platform::LIBSUFFIX}" }
    ffi_lib lib_paths + [lib_name]

    # This represents a +zmq_poller_event_t+ as in:
    #
    #   typedef struct zmq_poller_event_t
    #   {
    #       void *socket;
    #       int fd;
    #       void *user_data;
    #       short events;
    #   } zmq_poller_event_t;
    class PollerEvent < FFI::Struct
      layout :socket, :pointer,
             :fd, :int,
             :user_data, :pointer,
             :events, :short

      # @return [Boolean] whether the socket is readable
      def readable?
        (self[:events] & POLLIN) > 0
      end

      # @return [Boolean] whether the socket is writable
      def writable?
        (self[:events] & POLLOUT) > 0
      end
    end

#ZMQ_EXPORT void *zmq_poller_new (void);
#ZMQ_EXPORT int  zmq_poller_destroy (void **poller_p);
#ZMQ_EXPORT int  zmq_poller_add (void *poller, void *socket, void *user_data, short events);
#ZMQ_EXPORT int  zmq_poller_modify (void *poller, void *socket, short events);
#ZMQ_EXPORT int  zmq_poller_remove (void *poller, void *socket);
#ZMQ_EXPORT int  zmq_poller_wait (void *poller, zmq_poller_event_t *event, long timeout);

    # Gracefully attaches a function. If it's not available, this creates
    # a placeholder class method which, when called, simply raises
    # NotImplementedError with a helpful message.
    def self.attach_function(function_nickname, function_name, *args)
      super
    rescue ::FFI::NotFoundError
      if $VERBOSE || $DEBUG
        warn "CZTop: The ZMQ function #{function_name}() is not available. Don't use CZTop::Poller."
      end
      define_singleton_method(function_nickname) do |*|
        raise NotImplementedError, "compile ZMQ with --enable-drafts"
      end
    end

    opts = {
      blocking: true  # only necessary on MRI to deal with the GIL.
    }
    attach_function :poller_new, :zmq_poller_new, [], :pointer, **opts
    attach_function :poller_destroy, :zmq_poller_destroy,
      [:pointer], :int, **opts
    attach_function :poller_add, :zmq_poller_add,
      [:pointer, :pointer, :pointer, :short], :int, **opts
    attach_function :poller_modify, :zmq_poller_modify,
      [:pointer, :pointer, :short], :int, **opts
    attach_function :poller_remove, :zmq_poller_remove,
      [:pointer, :pointer], :int, **opts
    attach_function :poller_wait, :zmq_poller_wait,
      [:pointer, :pointer, :long], :int, **opts
  end
end
