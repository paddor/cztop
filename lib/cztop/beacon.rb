module CZTop
  # Used for LAN discovery and presence.
  #
  # This is implemented using an {Actor}.
  #
  # @see http://api.zeromq.org/czmq3-0:zbeacon
  class Beacon
    include ::CZMQ::FFI

    # function pointer to the `zbeacon()` function
    ZBEACON_FPTR = ::CZMQ::FFI.ffi_libraries.each do |dl|
      fptr = dl.find_function("zbeacon")
      break fptr if fptr
    end
    raise LoadError, "couldn't find zbeacon()" if ZBEACON_FPTR.nil?

    # Initialize new Beacon.
    def initialize
      @actor = Actor.new(ZBEACON_FPTR)
    end

    # @return [Actor] the actor behind this Beacon
    attr_reader :actor

    # Terminates the beacon.
    # @return [void]
    def terminate
      @actor.terminate
    end

    # Enable verbose logging of commands and activity.
    # @return [void]
    def verbose!
      @actor << "VERBOSE"
    end

    # Run the beacon on the specified UDP port.
    # @param port [Integer] port number to
    # @return [String] hostname, which can be used as endpoint for incoming
    #   connections
    # @raise [Errno::ENOTSUP] if the system doesn't support UDP broadcasts
    def configure(port)
      @actor.send_picture("si", :string, "CONFIGURE", :int, port)
      hostname = Zstr.recv(@actor)
      return hostname unless hostname.empty?
      raise Errno::ENOTSUP, "system doesn't support UDP broadcasts"
    end

    # @return [Integer] maximum length of data to {#publish}
    MAX_BEACON_DATA = 255

    # Start broadcasting a beacon.
    # @param data [String] data to publish
    # @param interval [Integer] interval in msec
    # @raise [ArgumentError] if data is longer than {MAX_BEACON_DATA} bytes
    # @return [void]
    def publish(data, interval)
      raise ArgumentError, "data too long" if data.bytesize > MAX_BEACON_DATA
      @actor.send_picture("sbi", :string, "PUBLISH", :string, data,
                              :int, data.bytesize, :int, interval)
    end

    # Stop broadcasting the beacon.
    # @return [void]
    def silence
      @actor << "SILENCE"
    end

    # Start listening to beacons from peers.
    # @param filter [String] do a prefix match on received beacons
    # @return [void]
    def subscribe(filter)
      @actor.send_picture("sb", :string, "SUBSCRIBE",
                          :string, filter, :int, filter.bytesize)
    end

    # Just like {#subscribe}, but subscribe to all peer beacons.
    # @return [void]
    def listen
      @actor.send_picture("sb", :string, "SUBSCRIBE",
                          :string, nil, :int, 0)
    end

    # Stop listening to other peers.
    # @return [void]
    def unsubscribe
      @actor << "UNSUBSCRIBE"
    end

    # Receive next beacon from a peer.
    # @return [Message] 2-frame message with ([ipaddr, data])
    def receive
      @actor.receive
    end
  end
end
