class CZTop::Loop

  # @abstract
  class Timer
    include ::CZMQ::FFI

    # @return [Integer] the timer ID
    attr_reader :id

    # @return [Loop] the associated reactor
    attr_reader :loop

    # This will {#register} this timer. So a subclass should ensure the needed
    # ivars are set before calling super().
    def initialize
      register
    end

    # @abstract
    # Used to actually create this timer. It should also call
    # {Loop#remember_timer} to retain a reference to itself.
    # @return [void]
    def register
      raise NotImplementedError
    end
    private :register

    # @abstract
    # Used to cancel this timer.
    # @return [void]
    def cancel
      raise NotImplementedError
    end

    # Calls the Proc saved, passing itself. If the Proc raises an exception,
    # it'll report failure to the reactor to make it terminate and re-raise
    # the exception.
    # @return [0] if the proc didn't raise an exception
    # @return [-1] if the proc raised an exception
    def call
      @proc.call(self)
      0 # report success, reactor can continue
    rescue
      @loop.exception = $! # so Loop#start can raise it
      -1 # report failure so reactor will terminate
    end
  end

  # Simple timer, which allows each timer to have its own delay and number
  # of times to expire. But can have a bad impact on performance if more
  # than a few (>100) are used. In that case, use {TicketTimer}s.
  class SimpleTimer < Timer
    # @return [Integer] the delay
    attr_reader :delay

    # @return [Integer] number of times to expire
    attr_reader :times

    # Register a new timer for the given loop.
    # @param delay [Integer] delay before expiry in msec
    # @param times [Integer] number of times to expire, or 0 to run forever
    # @param loop [CZTop::Loop] associated reactor
    # @yieldparam self [SimpleTimer] this timer
    def initialize(delay, times, loop, &blk)
      @delay, @times, @loop, @proc = delay, times, loop, blk
      @expired = 0
      @handler = Zloop.timer_fn { expired; call }
      super()
    end

    # Actually creates the timer using the handler.
    # @return [void]
    def register
      @id = @loop.ffi_delegate.timer(@delay, @times, @handler, nil)
      raise Error, "adding timer failed" if @id == -1
      @loop.remember_timer(self)
    end
    private :register

    # Cancels and forgets the timer.
    # @return [void]
    def cancel
      @loop.ffi_delegate.timer_end(@id)
      @loop.forget_timer(self)
    end

    private

    # Used to avoid memory leak in case this timer won't be explicitly
    # canceled. It'll track how many times this timer has expired and remove
    # its reference from the loop as soon as it has expired {#times} times.
    # @return [void]
    def expired
      @expired += 1
      @loop.forget_timer(self) if @expired == @times
    end
  end

  # More efficient timers. These are useful when you have thousands of
  # timers.
  class TicketTimer < Timer
    # Register a new timer for the given loop.
    # @param loop [CZTop::Loop] associated reactor
    # @yieldparam self [TicketTimer] this timer
    def initialize(loop, &blk)
      @loop, @proc = loop, blk
      @handler = Zloop.timer_fn do
        # avoid memory leak in case timer won't be canceled explicitly
        @loop.forget_timer(self)

        call
      end
      super()
    end

    # Timer ID of ticket timers is always 0.
    # @return [0]
    def id() 0 end

    # Resets the timer so it'll expire again.
    # @return [void]
    def reset
      @loop.ffi_delegate.ticket_reset(@ptr)
      @loop.remember_timer(self)
    end

    # Actually creates the timer using the handler.
    # @return [void]
    def register
      @ptr = @loop.ffi_delegate.ticket(@handler, nil)
      raise Error, "couldn't create ticket timer" if @ptr.null?
      @loop.remember_timer(self)
    end
    private :register

    # Cancels and forgets the timer.
    # @return [void]
    def cancel
      @loop.ffi_delegate.ticket_delete(@ptr)
      @loop.forget_timer(self)
    end
  end
end
