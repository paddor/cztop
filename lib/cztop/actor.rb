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
    # @param c_args [FFI::Pointer, nil] args, only useful if callback is an
    #   FFI::Pointer
    # @yieldparam message [Message]
    # @yieldparam pipe [Socket::PAIR]
    # @see #process_messages
    def initialize(callback = nil, c_args = nil, &handler)
      @running = true
      @zactor_mtx = Mutex.new # mutex for zactor_t resource
      @state_mtx = Mutex.new # mutex for actor state (like @running)
      @callback = mk_callback_shim(callback || handler)
      ffi_delegate = Zactor.new(@callback, c_args)
      attach_ffi_delegate(ffi_delegate)
      signal_handler_termination if shimmed_handler?
    end

    # Send a message to the actor.
    # @param message [Object] message to send to the actor, see {Message.coerce}
    # @return [self] so it's chainable
    # @raise [DeadActorError] if actor is terminated
    # @note Normally this method is asynchronous, but if the message is
    #   "$TERM", it blocks until the actor is terminated.
    def <<(message)
      message = Message.coerce(message)

      if TERM == message[0]
        # NOTE: can't just send this to the actor. The sender might call
        # #terminate immediately, which most likely causes a hang due to race
        # conditions.
        terminate
      else
        @state_mtx.synchronize do
          raise DeadActorError if not @running
          @zactor_mtx.synchronize { super }
        end
      end
      self
    end

    # Receive a message from the actor.
    # @return [Message]
    # @raise [DeadActorError] if actor is terminated
    def receive
      raise DeadActorError if not @running
      @zactor_mtx.synchronize do
        super
      end
    end

    # Same as {#<<}, but also waits for a response from the actor and returns
    # it.
    # @param message [Message] the request to the actor
    # @return [Message] the actor's response
    # @raise [ArgumentError] if the message is "$TERM" (use {#terminate})
    def request(message)
      raise DeadActorError if not @running
      message = Message.coerce(message)
      raise ArgumentError, "use #terminate" if TERM == message[0]
      @zactor_mtx.synchronize do
        message.send_to(self)
        Message.receive_from(self)
      end
    end

    # Sends a message according to a "picture".
    # @see zsock_send() on http://api.zeromq.org/czmq3-0:zsock
    # @note Mainly added for {Beacon}. If implemented there, it wouldn't be
    #   thread safe. And it's not that useful to be added to
    #   {SendReceiveMethods}.
    # @param picture [String] message's part types
    # @param args [String, Integer, ...] values, in FFI style (each one
    #   preceeded with it's type, like <tt>:string, "foo"</tt>)
    # @return [void]
    def send_picture(picture, *args)
      raise DeadActorError if not @running
      @zactor_mtx.synchronize do
        Zsock.send(ffi_delegate, picture, *args)
      end
    end

    # Thread-safe {PolymorphicZsockMethods#wait}.
    # @return [Integer]
    def wait
      @zactor_mtx.synchronize do
        super
      end
    end

    # Tells the actor to terminate and waits for it. Idempotent.
    # @return [Boolean] whether it died just now (+false+ if it was dead
    #   already)
    def terminate
      @state_mtx.synchronize do
        return false if not @running
        Message.new(TERM).send_to(self)
        wait_for_handler_to_die
        true
      end
    end

    # @return [Boolean] whether this actor has been terminated
    def terminated?
      !@running
    end

    private

    # Creates the callback shim, in case the handler isn't already an
    # FFI::Pointer. The shim is used to ensure we're notified when the handler
    # has terminated.
    #
    # In case the given handler is an FFI::Pointer (to a C function), it's
    # used as-is.  The handler has to do the handshake (signal) itself.
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
      if handler.is_a? ::FFI::Pointer
        handler # use it as-is

      elsif handler.respond_to?(:call)
        @handler_thread = nil
        @handler_dead_signal = Queue.new # used for signaling
        @handler_dying_signal = Queue.new # used for signaling

        Zactor.fn do |pipe_delegate, _args|
          begin
            @handler_thread = Thread.current
            @pipe = Socket::PAIR.from_ffi_delegate(pipe_delegate)
            @pipe.signal # handshake, so zactor_new() returns
            process_messages(handler)
          rescue Exception
            warn "Handler of #{self} raised exception: #{$!.inspect}"
            # TODO: store it?
          ensure
            @handler_dying_signal.push(nil)
          end
        end
      else
        raise ArgumentError, "invalid handler"
      end
    end

    # @return [Boolean] whether the handler is a Ruby object (as opposed to
    #   a C function)
    def shimmed_handler?
      !!@handler_thread # if it exists, it's shimmed
    end

    # the command which causes an actor handler to terminate
    TERM = "$TERM".freeze

    # Successively receive messages that were sent to the actor and
    # yield them to the given handler to process them. The a pipe (a
    # {Socket::PAIR} socket) is also passed to the handler so it can send back
    # the result of a command, if needed.
    #
    # When a message is "$TERM", or when the waiting for a message is
    # interrupted, execution is aborted and the actor will terminate.
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
          break if TERM == message[0]
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
    # Ruby handler.
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

        # NOTE: we do this here and not in #terminate, so it also works when
        # actor isn't terminated using #terminate, and #terminated? won't
        # block forever
        @running = false

        @handler_dead_signal.push(nil)
      end
    end

    # Waits for the C or Ruby handler to die.
    # @return [void]
    def wait_for_handler_to_die
      if shimmed_handler?
        # for Ruby block/Proc object handlers
        @handler_dead_signal.pop

      else
        # for handlers that are passed as C functions

        wait # relying on normal death signal
        @running = false
      end
    end
  end
end
