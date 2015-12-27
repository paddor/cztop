module CZTop
  # Represents a CZMQ::FFI::Zactor.
  #
  # = About Thread-Safety
  # The instance methods of this class are thread-safe. So it's safe to call
  # {#<<}, {#request} or even {#terminate} from different threads. Caution:
  # Use only these methods to communicate with the low-level zactor. Don't use
  # {Message#send_to} directly to send itself to an {Actor} instance, as it
  # wouldn't be thread-safe.
  #
  # = About termination
  # Actors should be terminated explicitly, either by sending them the "$TERM"
  # command or by calling {#terminate} (which does the same). Not terminating
  # them explicitly might make the process block at exit.
  #
  # @see http://api.zeromq.org/czmq3-0:zactor
  class Actor
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ZsockOptions
    include SendReceiveMethods
    include PolymorphicZsockMethods
    include ::CZMQ::FFI

    # Raised when trying to interact with a terminated actor.
    class DeadActorError < RuntimeError; end

    # Creates a new actor. Either pass a callback directly or a block. The
    # block will be called for every received message.
    #
    # @param callback [FFI::Pointer, Proc, #call] pointer to a C function or
    #   just anything callable
    # @param ffi_args [FFI::Pointer, nil] args, only useful if callback is an
    #   FFI::Function
    # @yieldparam message [Message]
    # @yieldparam pipe [Socket::PAIR]
    # @see #process_messages
    def initialize(callback = nil, ffi_args = nil, &handler)
      @running = true
      @zactor_mtx = Mutex.new # mutex for zactor_t resource
      @state_mtx = Mutex.new # mutex for actor state (like @running)
      @handler_thread = nil
      @handler_dead_signal = Queue.new # used for signaling
      @handler_dying_signal = Queue.new # used for signaling
      @callback = mk_callback_shim(callback || handler)
      ffi_delegate = Zactor.new(@callback, ffi_args)
      attach_ffi_delegate(ffi_delegate)
      signal_handler_termination
    end

    # Same as {SendReceiveMethods#<<}, but raises if actor is terminated.
    # @param message [Object] message to send to the actor, see {Message.coerce}
    # @return [self]
    # @raise [DeadActorError] if actor is terminated
    def <<(message)
      raise DeadActorError if not @running
      @zactor_mtx.synchronize do
        super
      end
      self
    end

    # Same as {#<<}, but also waits for a response from the actor and returns
    # it.
    # @param message [Message] the request to the actor
    # @return [Message] the actor's response
    def request(message)
      raise DeadActorError if not @running
      message = Message.coerce(message)
      @zactor_mtx.synchronize do
        message.send_to(self)
        Message.receive_from(self)
      end
    end

    # Tells the actor to terminate and waits for it. Idempotent.
    # @return [Boolean] whether it died just now (+false+ if it was dead
    #   already)
    def terminate
      @state_mtx.synchronize do
        return false if not @running
        self << "$TERM"
        @handler_dead_signal.pop # wait for handler to return
        true
      end
    end

    # @return [Boolean] whether this actor has been terminated
    def terminated?
      !@running
    end

    private

    # Creates the callback shim. The shim is used to ensure we're notified
    # when the handler has terminated.
    #
    # In case the given handler is an FFI::Function, it's used as-is. The shim
    # will just pass through the pipe and args. The handler has to do the
    # handshake (signal) itself.
    #
    # Otherwise, if it's a Proc or anything else responding to #call, does
    # the handshake then starts receiving messages, passing them to the
    # handler (see {#process_messages}).
    #
    # @param handler [Proc, FFI::Pointer, #call] the handler used to process
    #   messages
    # @return [FFI::Function] the callback function to be passed to the zactor
    # @raise [ArgumentError] if no handler is given
    def mk_callback_shim(handler)
      if !handler.respond_to?(:call) && !handler.is_a?(::FFI::Pointer)
        raise ArgumentError, "invalid handler"
      end
      Zactor.fn do |pipe_delegate, args|
        begin
          @handler_thread = Thread.current
          if handler.is_a? ::FFI::Function
            # pass callback through
            handler.call(pipe_delegate, args)
          else
            @pipe = Socket::PAIR.from_ffi_delegate(pipe_delegate)
            @pipe.signal # handshake, so zactor_new() returns
            process_messages(handler)
          end
        rescue Exception
          warn "Handler of #{self} raised exception: #{$!.inspect}"
          # TODO: store it?
        ensure
          @handler_dying_signal.push(nil)
        end
      end
    end

    # Successively receive messages that were sent to the actor and
    # yield them to the given block to process them. The block
    # also gets access to the pipe (a {Socket::PAIR} socket) to the actor so
    # it can send back the result of a command, if needed.
    #
    # When waiting for a message is interrupted, execution is aborted and the
    # actor will terminate.
    #
    # @param handler [Proc, #call] the handler used to process messages
    # @yieldparam message [Message] message (e.g. command) received
    # @yieldparam pipe [Socket::PAIR] pipe to write back something into the actor
    def process_messages(handler)
      while true
        begin
          message = next_message
        rescue Interrupt
          break
        else
          break if "$TERM" == message.frames.first.to_s
        end

        handler.call(message, @pipe)
      end
    end

    # Receives the next message even across any interrupts.
    # @return [Message] the next message
    def next_message
      @pipe.receive
    end

    # Creates a new thread that will signal the definitive termination of the
    # handler.
    #
    # This is needed to avoid the race condition between zactor_destroy()
    # which will wait for a signal from the handler in case it was able to
    # send the "$TERM" command, and the @callback which might still haven't
    # returned, but doesn't receive any messages anymore.
    #
    # @return [void]
    def signal_handler_termination
      # NOTE: has to be called in the main thread directly after starting the
      # handler. If started in the `ensure` block, it won't work on Rubinius.
      # See https://github.com/rubinius/rubinius/issues/3545

      # NOTE: can't just use ConditionVariable, as the signaling code might be
      # run BEFORE the waiting code.

      Thread.new do
        @handler_dying_signal.pop
        sleep 0.01 while @handler_thread.alive?
        @running = false

        @handler_dead_signal.push(nil)
      end
    end
  end
end
