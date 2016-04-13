module CZTop
  # A non-trivial socket poller.
  #
  # It can poll for readability and writability, and supports thread-safe
  # sockets (SERVER/CLIENT/RADIO/DISH).
  #
  # This implementation is NOT based on CZMQ's +zpoller+. Reasons:
  #
  # * +zpoller+ can only poll for readability
  #
  class Poller
    include ::CZMQ::FFI

    # @param readers [Socket, Actor] sockets to poll for input
    def initialize(*readers)
      @sockets = {} # needed to return the same socket objects
      @events = {} # event masks for each socket
      @poller_ptr = ZMQ.poller_new
      ObjectSpace.define_finalizer(@poller_ptr,
        Proc.new do
          ptr_ptr = ::FFI::MemoryPointer.new :pointer
          ptr_ptr.write_pointer(@poller_ptr)
          ZMQ.poller_destroy(ptr_ptr)
        end)
      @event_ptr = FFI::MemoryPointer.new(ZMQ::PollerEvent)
      readers.each { |r| add_reader(r) }
    end

    # Adds a socket to be polled for readability.
    # @param socket [Socket, Actor] the socket
    # @param events [Integer] bitwise-OR'd events you're interested in (see
    #   POLLIN and POLLOUT constants in {CZTop::Poller::ZMQ}
    # @return [void]
    # @raise [ArgumentError] if it's not a socket
    def add(socket, events)
      ptr = ptr_for_socket(socket)
      rc = ZMQ.poller_add(@poller_ptr, ptr, nil, events)
      HasFFIDelegate.raise_zmq_err if rc == -1
      remember_socket(socket, events)
    end

    # Convenience method to register a socket for readability. See {#add}.
    # @param socket [Socket, Actor] the socket
    # @return [void]
    def add_reader(socket)
      add(socket, ZMQ::POLLIN)
    end

    # Convenience method to register a socket for writability. See {#add}.
    # @param socket [Socket, Actor] the socket
    # @return [void]
    def add_writer(socket)
      add(socket, ZMQ::POLLOUT)
    end

    # Modifies the events of interest for the given socket.
    # @param socket [Socket, Actor] the socket
    # @param events [Integer] events you're interested in (see constants in
    #   {ZMQ}
    # @return [void]
    # @raise [ArgumentError] if it's not a socket
    def modify(socket, events)
      ptr = ptr_for_socket(socket)
      rc = ZMQ.poller_modify(@poller_ptr, ptr, events)
      HasFFIDelegate.raise_zmq_err if rc == -1
      remember_socket(socket, events)
    end

    # Removes a previously registered socket. Won't raise if you're
    # trying to remove a socket that's not registered.
    # @param socket [Socket, Actor] the socket
    # @return [void]
    # @raise [ArgumentError] if it's not a socket
    def remove(socket)
      ptr = ptr_for_socket(socket)
      rc = ZMQ.poller_remove(@poller_ptr, ptr)
      HasFFIDelegate.raise_zmq_err if rc == -1
      forget_socket(socket)
    end

    # Removes a reader socket that was registered for readability only.
    #
    # @param socket [Socket, Actor] the socket
    # @raise [ArgumentError] if it's not registered, not registered for
    #   readability, or registered for more than just readability
    def remove_reader(socket)
      if event_mask_for_socket(socket) == ZMQ::POLLIN
        remove(socket)
        return
      end
      raise ArgumentError, "not registered for readability only: %p" % socket
    end

    # Removes a reader socket that was registered for writability only.
    #
    # @param socket [Socket, Actor] the socket
    # @raise [ArgumentError] if it's not registered, not registered for
    #   writability, or registered for more than just writability
    def remove_writer(socket)
      if event_mask_for_socket(socket) == ZMQ::POLLOUT
        remove(socket)
        return
      end
      raise ArgumentError, "not registered for writability only: %p" % socket
    end

    # Waits for registered sockets to become readable or writable, depending
    # on what you're interested in.
    #
    # @param timeout [Integer] how long to wait in ms, or 0 to avoid blocking,
    #   or -1 to wait indefinitely
    # @return [Event] the first event of interest
    # @return [nil] if the timeout expired or
    # @raise [SystemCallError] if this failed
    def wait(timeout = -1)
      rc = ZMQ.poller_wait(@poller_ptr, @event_ptr, timeout)
      if rc == -1
        if CZMQ::FFI::Errors.errno != Errno::ETIMEDOUT::Errno
          HasFFIDelegate.raise_zmq_err
        end
        return nil
      end
      return Event.new(self, @event_ptr)
    end

    # Simpler version of {#wait}, which just returns the first socket of
    # interest, if any. This is useful if you either have only reader sockets,
    # or only have writer sockets.
    # @param timeout [Integer] how long to wait in ms, or 0 to avoid blocking,
    #   or -1 to wait indefinitely
    # @return [Socket, Actor] first socket of interest
    # @return [nil] if timeout expired
    # @raise [SystemCallError] if this failed
    def simple_wait(timeout = -1)
      event = wait(timeout)
      return event.socket if event
    end

    # @param ptr [FFI::Pointer] pointer to the socket
    # @return [Socket, Actor] socket corresponding to given pointer
    # @raise [ArgumentError] if pointer is not known
    def socket_for_ptr(ptr)
      @sockets[ptr.to_i] or
        raise ArgumentError, "no socket known for pointer %p" % ptr
    end

    # @return [Array<CZTop::Socket>] all sockets registered with this poller
    # @note The actual events registered for each sockets don't matter.
    def sockets
      @sockets.values
    end

    # Returns the event mask for the given, registered socket.
    # @param socket [Socket, Actor] which socket's events to return
    # @return [Integer] event mask for the given socket
    # @raise [ArgumentError] if socket is not registered
    def event_mask_for_socket(socket)
      @events[socket] or
        raise ArgumentError, "no event mask known for socket %p" % socket
    end

    private

    # @param socket [Socket, Actor] the socket
    # @return [FFI::Pointer] low-level handle
    # @raise [ArgumentError] if argument is not a socket
    def ptr_for_socket(socket)
      raise ArgumentError unless socket.is_a?(Socket) || socket.is_a?(Actor)
      Zsock.resolve(socket)
    end

    # Keeps a reference to the given socket, and remembers its event mask.
    # @param socket [Socket, Actor] the socket
    # @param events [Integer] the event mask
    def remember_socket(socket, events)
      @sockets[ptr_for_socket(socket).to_i] = socket
      @events[socket] = events
    end

    # Discards the referencel to the given socket, and forgets its event mask.
    # @param socket [Socket, Actor] the socket
    def forget_socket(socket)
      @sockets.delete(ptr_for_socket(socket).to_i)
      @events.delete(socket)
    end

    # Represents an event returned by {CZTop::Poller#wait}. This is useful to
    # find out whether the associated socket is now readable or writable, in
    # case you're interested in both. For a simpler variant, check out
    # {CZTop::Poller#simple_wait}.
    class Event
      # @param poller [CZTop::Poller] the poller instance
      # @param event_ptr [FFI::Pointer] pointer to the memory allocated for
      #   the event's data (a +zmq_poller_event_t+)
      def initialize(poller, event_ptr)
        @poller = poller
        @poller_event = ZMQ::PollerEvent.new(event_ptr)
      end

      # @return [Socket, Actor] the associated socket
      def socket
        @socket ||= @poller.socket_for_ptr(@poller_event[:socket])
      end

      # @return [Boolean] whether it's readable
      def readable?
        @poller_event.readable?
      end

      # @return [Boolean] whether it's writable
      def writable?
        @poller_event.writable?
      end
    end
  end

  # This is a poller which is able to provide a list of readable and a list
  # of writable sockets. This is useful for when you need to process socket
  # events in batch, rather than one per event loop iteration.
  #
  # In particular, this is needed in Celluloid::ZMQ, where in a call to
  # Celluloid::ZMQ::Reactor#run_once all readable/writable sockets need to
  # be processed.
  #
  # = Implementation
  #
  # It wraps a {CZTop::Poller} and just does the following to support
  # getting an array of readable/writable sockets:
  #
  # * in {#wait}, poll with given timeout
  # * in case there was an event, poll again with zero timeout until no more
  #   sockets
  # * accumulate results into two lists
  #
  class Poller::Aggregated

    # @return [CZTop::Poller.new] the associated (regular) poller
    attr_reader :poller

    # @return [Array<CZTop::Socket>] readable sockets
    attr_reader :readables

    # @return [Array<CZTop::Socket>] writable sockets
    attr_reader :writables

    # Initializes the aggregated poller.
    # @param poller [CZTop::Poller] the wrapped poller
    def initialize(poller = CZTop::Poller.new)
      @readables = []
      @writables = []
      @poller = poller
    end

    # Forgets all previous event information (which sockets are
    # readable/writable) and waits for events anew. After getting the first
    # event, {CZTop::Poller#wait} is called again with a zero-timeout to get
    # all pending events to extract them into the aggregated lists of
    # readable and writable sockets.
    #
    # For every event, the corresponding event mask flag is disabled for the
    # associated socket, so it won't turn up again. Finally, all event masks
    # are restored to what they were before the call to this method.
    #
    # @param timeout [Integer] how long to wait in ms, or 0 to avoid blocking,
    #   or -1 to wait indefinitely
    # @return [Boolean] whether there have been any events
    def wait(timeout = -1)
      @readables = []
      @writables = []
      @event_masks = {}

      if event = @poller.wait(timeout)
        extract(event)

        # get all other pending events, if any, but no more blocking
        while event = @poller.wait(0)
          extract(event)
        end

        restore_event_masks
        return true
      end
      return false
    end

    private

    # Extracts the event information, adds the socket to the correct list(s)
    # and modifies the socket's event mask for the socket to not turn up
    # again during the next call(s) to {CZTop::Poller#wait} within {#wait}.
    #
    # @param event [CZTop::Poller::Event]
    # @return [void]
    def extract(event)
      event_mask = poller.event_mask_for_socket(event.socket)
      @event_masks[event.socket] = event_mask
      if event.readable?
        @readables << event.socket
        event_mask &= 0xFFFF ^ CZTop::Poller::ZMQ::POLLIN
      end
      if event.writable?
        @writables << event.socket
        event_mask &= 0xFFFF ^ CZTop::Poller::ZMQ::POLLOUT
      end
      poller.modify(event.socket, event_mask)
    end

    # Restores the event mask for all registered sockets to the state they
    # were before the call to {#wait}.
    # @return [void]
    def restore_event_masks
      @event_masks.each { |socket, mask| poller.modify(socket, mask) }
    end
  end

  # CZTop's interface to the low-level +zmq_poll()+ function.
  module Poller::ZMQ

    POLL    = 1
    POLLIN  = 1
    POLLOUT = 2
    POLLERR = 4

    extend ::FFI::Library
    lib_name = 'libzmq'
    lib_paths = ['/usr/local/lib', '/opt/local/lib', '/usr/lib64']
      .map { |path| "#{path}/#{lib_name}.#{::FFI::Platform::LIBSUFFIX}" }
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

  # This is the trivial poller based on zpoller. It only supports polling
  # for readability, but it also supports doing that on CLIENT/SERVER sockets,
  # which is useful for {CZTop::Poller}.
  #
  # @see http://api.zeromq.org/czmq3-0:zpoller
  class Poller::ZPoller
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ::CZMQ::FFI

    # Initializes the Poller. At least one reader has to be given.
    # @param reader [Socket, Actor] socket to poll for input
    # @param readers [Socket, Actor] any additional sockets to poll for input
    def initialize(reader, *readers)
      @sockets = {} # to keep references and return same instances
      ptr = Zpoller.new(reader,
                        *readers.flat_map {|r| [ :pointer, r ] },
                        :pointer, nil)
      attach_ffi_delegate(ptr)
      remember_socket(reader)
      readers.each { |r| remember_socket(r) }
    end

    # Adds another reader socket to the poller.
    # @param reader [Socket, Actor] socket to poll for input
    # @return [void]
    # @raise [SystemCallError] if this fails
    def add(reader)
      rc = ffi_delegate.add(reader)
      raise_zmq_err("unable to add socket %p" % reader) if rc == -1
      remember_socket(reader)
    end

    # Removes a reader socket from the poller.
    # @param reader [Socket, Actor] socket to remove
    # @return [void]
    # @raise [ArgumentError] if socket was invalid, e.g. it wasn't registered
    #   in this poller
    # @raise [SystemCallError] if this fails for another reason
    def remove(reader)
      rc = ffi_delegate.remove(reader)
      raise_zmq_err("unable to remove socket %p" % reader) if rc == -1
      forget_socket(reader)
    end

    # Waits and returns the first socket that becomes readable.
    # @param timeout [Integer] how long to wait in ms, or 0 to avoid
    #   blocking, or -1 to wait indefinitely
    # @return [Socket, Actor] first socket of interest
    # @return [nil] if the timeout expired or
    # @raise [Interrupt] if the timeout expired or
    def wait(timeout = -1)
      ptr = ffi_delegate.wait(timeout)
      if ptr.null?
        raise Interrupt if ffi_delegate.terminated
        return nil
      end
      return socket_by_ptr(ptr)
    end

    # Tells the zpoller to ignore interrupts. By default, {#wait} will return
    # immediately if it detects an interrupt (when +zsys_interrupted+ is set
    # to something other than zero). Calling this method will supress this
    # behavior.
    # @return [void]
    def ignore_interrupts
      ffi_delegate.ignore_interrupts
    end

    # By default the poller stops if the process receives a SIGINT or SIGTERM
    # signal. This makes it impossible to shut-down message based architectures
    # like zactors. This method lets you switch off break handling. The default
    # nonstop setting is off (false).
    #
    # Setting this will cause {#wait} to never raise.
    #
    # @param flag [Boolean] whether the poller should run nonstop
    def nonstop=(flag)
      ffi_delegate.set_nonstop(flag)
    end

    private

    # Remembers the socket so a call to {#wait} can return with the exact same
    # instance of {Socket}, and it also makes sure the socket won't get
    # GC'd.
    # @param socket [Socket, Actor] the socket instance to remember
    # @return [void]
    def remember_socket(socket)
      @sockets[socket.to_ptr.to_i] = socket
    end

    # Forgets the socket because it has been removed from the poller.
    # @param socket [Socket, Actor] the socket instance to forget
    # @return [void]
    def forget_socket(socket)
      @sockets.delete(socket.to_ptr.to_i)
    end

    # Gets the previously remembered socket associated to the given pointer.
    # @param ptr [FFI::Pointer] the pointer to a socket
    # @return [Socket, Actor] the socket associated to the given pointer
    # @raise [SystemCallError] if no socket is registered under given pointer
    def socket_by_ptr(ptr)
      @sockets[ptr.to_i] or
        # NOTE: This should never happen, since #wait will return nil if
        # +zpoller_wait+ returned NULL. But it's better to fail early in case
        # it ever returns a wrong pointer.
        raise_zmq_err("no socket known for pointer #{ptr.inspect}")
    end
  end
end
