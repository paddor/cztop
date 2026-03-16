# frozen_string_literal: true

module CZTop

  # Monitors ZMQ socket events (connections, disconnections, etc.)
  # via CZMQ's zmonitor actor.
  #
  # @note The monitor must be created before the events you want to
  #   observe, and closed before closing the monitored socket.
  #
  class Monitor

    # All supported ZMQ socket monitoring events.
    #
    EVENTS = %w[
      CONNECTED
      CONNECT_DELAYED
      CONNECT_RETRIED
      LISTENING
      BIND_FAILED
      ACCEPTED
      ACCEPT_FAILED
      CLOSED
      CLOSE_FAILED
      DISCONNECTED
      MONITOR_STOPPED
    ].freeze

    # A single monitoring event.
    #
    Event = Data.define(:name, :endpoint, :peer_address)


    # Creates a new monitor for the given socket.
    #
    # @param socket [CZTop::Socket] the socket to monitor
    # @param events [Array<String>] event names to listen for (default: all)
    # @param verbose [Boolean] enable CZMQ verbose logging
    #
    def initialize(socket, *events, verbose: false)
      zmonitor_fn = CZMQ::FFI::ZMONITOR_FN
      raise 'zmonitor not available in this CZMQ build' unless zmonitor_fn

      @actor_ptr = CZMQ::FFI.zactor_new(zmonitor_fn, socket.to_ptr)
      HasFFIDelegate.raise_zmq_err if @actor_ptr.null?

      @closed = false

      prevent_leak_ptr = ::FFI::MemoryPointer.new(:pointer)
      prevent_leak_ptr.write_pointer(@actor_ptr)
      ObjectSpace.define_finalizer(self, self.class._make_destructor(prevent_leak_ptr))

      CZMQ::FFI.zstr_send(@actor_ptr, 'VERBOSE') if verbose

      events = EVENTS if events.empty?
      events.each do |ev|
        CZMQ::FFI.zstr_sendm(@actor_ptr, 'LISTEN')
        CZMQ::FFI.zstr_send(@actor_ptr, ev)
      end

      CZMQ::FFI.zstr_send(@actor_ptr, 'START')
      CZMQ::FFI.zsock_wait(@actor_ptr)
    end


    # Receives the next monitoring event.
    #
    # @param timeout [Numeric] timeout in seconds
    # @return [Event, nil] the event, or nil on timeout
    #
    def receive(timeout: 0.1)
      CZMQ::FFI.zsock_set_rcvtimeo(@actor_ptr, (timeout * 1000).to_i)

      zmsg_ptr = CZMQ::FFI.zmsg_recv(@actor_ptr)
      return nil if zmsg_ptr.null?

      frames = []
      frame_ptr = CZMQ::FFI.zmsg_first(zmsg_ptr)
      until frame_ptr.null?
        data = CZMQ::FFI.zframe_data(frame_ptr)
        size = CZMQ::FFI.zframe_size(frame_ptr)
        frames << data.read_bytes(size).force_encoding(Encoding::UTF_8)
        frame_ptr = CZMQ::FFI.zmsg_next(zmsg_ptr)
      end

      pp = ::FFI::MemoryPointer.new(:pointer)
      pp.write_pointer(zmsg_ptr)
      CZMQ::FFI.zmsg_destroy(pp)

      Event.new(
        name:         frames[0],
        endpoint:     frames[1] || '',
        peer_address: frames[2]
      )
    end


    # Closes the monitor. Must be called before closing the monitored socket.
    #
    # @return [void]
    #
    def close
      return if @closed

      pp = ::FFI::MemoryPointer.new(:pointer)
      pp.write_pointer(@actor_ptr)
      CZMQ::FFI.zactor_destroy(pp)
      @closed = true
      ObjectSpace.undefine_finalizer(self)
    end


    # @return [Boolean] whether the monitor has been closed
    #
    def closed?
      @closed
    end


    # @api private
    #
    def self._make_destructor(prevent_leak_ptr)
      ->(_id) { CZMQ::FFI.zactor_destroy(prevent_leak_ptr) }
    end
  end
end
