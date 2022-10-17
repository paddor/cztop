# frozen_string_literal: true

module CZTop
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
  # * in case there was an event:
  #   * deregister the corresponding event(s) on the registered socket
  #   * poll again with zero timeout until no more sockets
  #   * repeat and accumulate results into two lists
  #
  # = Forwarded Methods
  #
  # The following methods are defined on this class too, and calls are
  # forwarded directly to the actual {CZTop::Poller} instance:
  #
  # * {CZTop::Poller#add}
  # * {CZTop::Poller#add_reader}
  # * {CZTop::Poller#add_writer}
  # * {CZTop::Poller#modify}
  # * {CZTop::Poller#remove}
  # * {CZTop::Poller#remove_reader}
  # * {CZTop::Poller#remove_writer}
  # * {CZTop::Poller#sockets}
  #
  class Poller::Aggregated
    # @return [CZTop::Poller.new] the associated (regular) poller
    attr_reader :poller

    # @return [Array<CZTop::Socket>] readable sockets
    attr_reader :readables

    # @return [Array<CZTop::Socket>] writable sockets
    attr_reader :writables

    extend Forwardable
    def_delegators :@poller,
                   :add,
                   :add_reader,
                   :add_writer,
                   :modify,
                   :remove,
                   :remove_reader,
                   :remove_writer,
                   :sockets

    # Initializes the aggregated poller.
    # @param poller [CZTop::Poller] the wrapped poller
    def initialize(poller = CZTop::Poller.new)
      @readables = []
      @writables = []
      @poller    = poller
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
      @readables   = []
      @writables   = []
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
      false
    end

    private

    # Extracts the event information, adds the socket to the correct list(s)
    # and modifies the socket's event mask for the socket to not turn up
    # again during the next call(s) to {CZTop::Poller#wait} within {#wait}.
    #
    # @param event [CZTop::Poller::Event]
    # @return [void]
    def extract(event)
      event_mask                 = poller.event_mask_for_socket(event.socket)
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
end
