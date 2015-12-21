require 'set'

module CZTop
  # CZMQ's reactor.
  # @see http://api.zeromq.org/czmq3-0:zloop
  class Loop
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ::CZMQ::FFI

    # used for various Loop errors
    class Error < RuntimeError; end

    # @return [Hash<Socket, Set<FFI::Function>] remembered handlers (callbacks)
    attr_reader :handlers

    # @return [Hash<Integer, Timer>] all timers by their timer ID
    attr_reader :timers

    # @return [Exception, nil] exception that got set by a handler (which
    #   would be raised by {#start} after the reactor has terminated
    attr_accessor :exception

    # Initializes the loop.
    def initialize
      attach_ffi_delegate(Zloop.new)
      @handlers = Hash.new { |h,k| h[k] = Set.new } # socket => Set<handler>
      @timers = {} # timer.id => Timer
    end

    # Add a handler for a socket.
    # @param socket [Socket] the socket to register and read from
    # @return [void]
    def add_reader(socket, &blk)
      handler = Zloop.reader_fn(&blk)
      rc = ffi_delegate.reader(socket.ffi_delegate, handler, nil)
      raise Error, "adding reader failed" if rc == -1
      @handlers[socket] << handler
    end

    # Remove all handlers for socket.
    # @param socket [Socket]
    # @return [void]
    def remove_reader(socket)
      ffi_delegate.reader_end(socket.ffi_delegate)
      @handlers.delete(socket)
    end

    # Tolerate errors on the socket. If not used, sockets that have errors
    # will be silently removed from the reactor.
    # @param socket [Socket]
    # @return [void]
    def tolerate_reader(socket)
      ffi_delegate.reader_set_tolerant(socket.ffi_delegate)
    end

    # Add a new timer.
    # @param delay [Integer] delay before expiry in msec
    # @param times [Integer] number of times to expire
    # @return [SimpleTimer]
    def after(delay, times: 1, &blk)
      SimpleTimer.new(delay, times, self, &blk)
    end

    # Add a new, reoccurring timer.
    # @param delay [Integer] delay before each expiry in msec
    # @return [SimpleTimer]
    def every(delay, &blk)
      SimpleTimer.new(delay, _times = 0, self, &blk)
    end

    # Used to remember the timer to keep a reference on the callback.
    # @param timer [Timer] the timer to remember
    # @return [Timer]
    def remember_timer(timer)
      @timers[timer.id] = timer
    end

    # Free explicitly canceled timer.
    # @param [Timer] timer to forget
    # @todo implicitly expired timers need a better solution
    # @return [void]
    def forget_timer(timer)
      @timers.delete(timer.id)
    end

    # Adds a new ticket timer.
    # @return [TicketTimer]
    # @raise [Error] if ticket delay isn't set
    def add_ticket_timer(&blk)
      raise Error, "ticket delay not set" if @ticket_delay.nil?
      TicketTimer.new(self, &blk)
    end

    # @return [Integer] ticket delay in ms
    attr_reader :ticket_delay

    # Sets the delay for new {TicketTimer}s.
    # @param new_delay [Integer] new delay in ms
    # @note Delay must be higher than the previous delay.
    # @return [new_delay]
    def ticket_delay=(new_delay)
      if @ticket_delay && (new_delay <= @previous_delay)
        raise ArgumentError, "must not decrease ticket delay"
      end
      ffi_delegate.set_ticket_delay(new_delay)
      @ticket_delay = new_delay
    end

    # Starts the reactor and blocks until it is terminated. This could happen
    # by a handler that raises an exception.
    # @return [void]
    # @raise [Exception] the exception raised by a handler
    def start
      reraise_handler_exception { ffi_delegate.start }
    end

    private

    # Reraises the exception set during the execution of the given block.
    # @return [void]
    def reraise_handler_exception
      self.exception = nil # clear any existing exception
      yield
      raise exception if exception # set by the last failed handler
    end
  end
end
