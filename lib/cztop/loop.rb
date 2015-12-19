require 'set'

module CZTop
  # CZMQ's reactor.
  # @see http://api.zeromq.org/czmq3-0:zloop
  class Loop
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ::CZMQ::FFI

    class Error < RuntimeError; end

    # @return [Set<FFI::Function>] remembered handlers (callbacks)
    attr_reader :handlers

    # @return [Hash<Integer, Timer>] all timers by their timer ID
    attr_reader :timers

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
      t = SimpleTimer.new(delay, times, self, &blk)
    ensure
      remember_timer(t) if t
    end

    # Add a new, reoccurring timer.
    # @param delay [Integer] delay before each expiry in msec
    # @return [SimpleTimer]
    def every(delay, &blk)
      t = SimpleTimer.new(delay, _times = 0, self, &blk)
    ensure
      remember_timer(t) if t
    end

    # @abstract
    class Timer
      # @return [Integer] the timer ID
      attr_reader :id

      # @return [Loop] the associated reactor
      attr_reader :loop

      def cancel
        raise NotImplementedError
      end
    end

    class SimpleTimer < Timer
      # @return [Integer] the delay
      attr_reader :delay

      # @return [Integer] number of times to expire
      attr_reader :times

      # Register a new timer for the given loop.
      # @param delay [Integer] delay before expiry in msec
      # @param times [Integer] number of times to expire, or 0 to run forever
      # @yieldparam self [Timer] this timer
      def initialize(delay, times, loop)
        @delay, @times, @loop = delay, times, loop
        @handler = Zloop.timer_fn { yield self }
        register
      end

      # Cancels this timer manually.
      # @return [void]
      def cancel
        Zloop.timer_end(@loop.ffi_delegate, @id)
        loop.forget_timer(self)
      end

      private

      # Actually creates the timer using the handler and registers itself in
      # the {Loop} to retain a reference on the handler.
      # @return [void]
      def register
        @id = @loop.ffi_delegate.timer(@delay, @times, @handler, nil)
        raise Error, "adding timer failed" if @id == -1
        @loop.remember_timer(self)
      end
    end

    # used to remember the timer to keep a reference on the callback
    # @return [Timer]
    def remember_timer(timer)
      @timers[timer.id] = timer
    end

    # Free explicitly canceled timer.
    # @param [Timer] timer to forget
    # @todo implicitly expired timers need a better solution
    def forget_timer(timer)
      @timers.delete(timer.id)
    end

    # Adds a new ticket timer.
    # @return [TicketTimer]
    def add_ticket_timer(&blk)
      raise Error, "ticket delay not set" if @ticket_delay.nil?
      t = TicketTimer.new(delay, &blk)
    ensure
      remember_timer(t) if t
    end

    # @note Delay must be higher than the previous delay.
    def ticket_delay=(new_delay)
      if @ticket_delay && (new_delay <= @previous_delay)
        raise ArgumentError, "must not decrease ticket delay"
      end
      ffi_delegate.set_ticket_delay(new_delay)
      @ticket_delay = new_delay
    end

    # More efficient timers. These are useful when you have thousands of
    # timers.
    class TicketTimer < Timer
      # Register a new timer for the given loop.
      # @param delay [Integer] delay before expiry in msec
      # @param times [Integer] number of times to expire, or 0 to run forever
      # @yieldparam self [Timer] this timer
      def initialize(loop)
        @loop = loop
        @handler = Zloop.timer_fn { yield self }
        register
      end

      # @return [FFI::Pointer]
      def id() @ptr end

      # @return [void]
      def reset
        @loop.ticket_reset(@ptr)
      end

      # @return [void]
      def cancel
        @loop.ticket_delete(@ptr)
        @loop.forget_timer(self)
      end

      private

      # Actually creates the timer using the handler and registers itself in
      # the {Loop} to retain a reference on the handler.
      # @return [void]
      def register
        @ptr = @loop.ffi_delegate.ticket(@handler, nil)
        @loop.remember_timer(self)
      end
    end

    # Start the reactor.
    # @return [void]
    def start
      ffi_delegate.start
    end
  end
end
