module CZTop
  # CZMQ monitor. Listen for socket events.
  #
  # This is implemented using an {Actor}.
  #
  # @note This works only on connection oriented transports, like TCP, IPC,
  #   and TIPC.
  # @see http://api.zeromq.org/czmq3-0:zmonitor
  # @see http://api.zeromq.org/4-1:zmq-socket-monitor
  class Monitor
    include ::CZMQ::FFI

    # function pointer to the +zmonitor()+ function
    ZMONITOR_FPTR = ::CZMQ::FFI.ffi_libraries.each do |dl|
      fptr = dl.find_function("zmonitor")
      break fptr if fptr
    end
    raise LoadError, "couldn't find zmonitor()" if ZMONITOR_FPTR.nil?

    # @param socket [Socket, Actor] the socket or actor to monitor
    def initialize(socket)
      @actor = Actor.new(ZMONITOR_FPTR, socket)
    end

    # @return [Actor] the actor behind this monitor
    attr_reader :actor

    # Terminates the monitor.
    # @return [void]
    def terminate
      @actor.terminate
    end

    # Enable verbose logging of commands and activity.
    # @return [void]
    def verbose!
      @actor << "VERBOSE"
    end

    # @return [Array<String>] types of valid events
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
      ALL
    ]

    # Configure monitor to listen for specific events.
    # @param events [String] one or more events from {EVENTS}
    # @return [void]
    def listen(*events)
      events.each do |event|
        EVENTS.include?(event) or
          raise ArgumentError, "invalid event: #{event.inspect}"
      end
      @actor << [ "LISTEN", *events ]
    end

    # Start the monitor. After this, you can read events using {#next}.
    # @return [void]
    def start
      @actor << "START"
      @actor.wait
    end

    # Get next event. This blocks until the next event is available.
    # @example
    #   socket = CZTop::Socket::ROUTER.new("tcp://127.0.0.1:5050")
    #   # ... normal stuff with socket
    #
    #   # do this in another thread, or using a Poller, so it's possible to
    #   # interact with the socket and the monitor
    #   Thread.new do
    #     monitor = CZTop::Monitor.new(socket)
    #     monitor.listen "CONNECTED", "DISCONNECTED"
    #     while event = monitor.next
    #       case event[0]
    #       when "CONNECTED"
    #         puts "a client has connected"
    #       when "DISCONNECTED"
    #         puts "a client has disconnected"
    #       end
    #     end
    #   end
    #
    # @return [String] one of the events from {EVENTS}, something like
    #   <tt>["ACCEPTED", "73", "tcp://127.0.0.1:55585"]</tt>
    def next
      @actor.receive
    end
  end
end
