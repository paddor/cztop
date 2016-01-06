module CZTop
  # Used for LAN discovery and presence.
  #
  # This is implemented using an {Actor}.
  #
  # @see http://api.zeromq.org/czmq3-0:zbeacon
  class Beacon
    include ::CZMQ::FFI

    # Used for {Beacon} errors.
    class Error < RuntimeError; end

    # function pointer to the `zbeacon()` function
    ZBEACON_FPTR = ::CZMQ::FFI.ffi_libraries.each do |dl|
      fptr = dl.find_function("zbeacon")
      break fptr if fptr
    end
    raise LoadError, "couldn't find zbeacon()" if ZBEACON_FPTR.nil?

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

    VERBOSE = "VERBOSE".freeze

    # Enable verbose logging of commands and activity.
    # @return [void]
    def verbose!
      @actor << VERBOSE
    end

    CONFIGURE_PIC = "si".freeze
    CONFIGURE = "CONFIGURE".freeze

    # Run the beacon on the specified UDP port.
    # @param port [Integer] port number to
    # @return [String] hostname, which can be used as endpoint for incoming
    #   connections
    # @raise [Error] if the system doesn't support UDP broadcasts
    def configure(port)
      @actor.send_picture(CONFIGURE_PIC, :string, CONFIGURE, :int, port)
      hostname = Zstr.recv(@actor)
      raise Error, "system doesn't support UDP broadcasts" if hostname.empty?
      return hostname
    end

    PUBLISH_PIC = "sbi".freeze
    PUBLISH = "PUBLISH".freeze
    MAX_BEACON_DATA = 255

    # Start broadcasting a beacon.
    # @param data [String] data to publish
    # @param interval [Integer] interval in msec
    # @raise [Error] if data is longer than {MAX_BEACON_DATA} bytes
    # @return [void]
    def publish(data, interval)
      raise Error, "data is too long" if data.bytesize > MAX_BEACON_DATA
      @actor.send_picture(PUBLISH_PIC, :string, PUBLISH, :string, data,
                              :int, data.bytesize, :int, interval)
    end

    SILENCE = "SILENCE".freeze

    # Stop broadcasting the beacon.
    # @return [void]
    def silence
      @actor << SILENCE
    end

    SUBSCRIBE_PIC = "sb".freeze
    SUBSCRIBE = "SUBSCRIBE".freeze

    # Start listening to beacons from peers.
    # @param filter [String] do a prefix match on received beacons
    # @return [void]
    def subscribe(filter)
      @actor.send_picture(SUBSCRIBE_PIC, :string, SUBSCRIBE,
                          :string, filter, :int, filter.bytesize)
    end

    # Just like {#subscribe}, but subscribe to all peer beacons.
    # @return [void]
    def listen
      @actor.send_picture(SUBSCRIBE_PIC, :string, SUBSCRIBE,
                          :string, nil, :int, 0)
    end

    UNSUBSCRIBE = "UNSUBSCRIBE".freeze

    # Stop listening to other peers.
    # @return [void]
    def unsubscribe
      @actor << UNSUBSCRIBE
    end

    # Receive next beacon from a peer.
    # @return [Message] 2-frame message with ([ipaddr, data])
    def receive
      @actor.receive
    end
  end
end
