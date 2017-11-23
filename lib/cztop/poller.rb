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
        case CZMQ::FFI::Errors.errno
        # NOTE: ETIMEDOUT for backwards compatibility, although this API is
          # still DRAFT.
        when Errno::EAGAIN::Errno, Errno::ETIMEDOUT::Errno
          return nil
        else
          HasFFIDelegate.raise_zmq_err
        end
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
end
