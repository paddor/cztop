module CZTop
  # Represents a CZMQ::FFI::Zactor.
  # @note Mainly because Proxy and Authenticator are actors.
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

    # Creates a new actor. If no callback is given, it'll create a generic one
    # which will yield every received command (first frame of an arriving
    # message).
    # @param callback [FFI::Function]
    # @yieldparam message [Message]
    # @yieldparam pipe [Socket::PAIR]
    # @see #process_messages
    def initialize(callback = nil, &task)
      @running = true
      @ptr_mtx = Mutex.new # mutex for zactor_t resource
      @state_mtx = Mutex.new # mutex for state of this object, like @running
      # NOTE: retain reference on callback
      @callback = callback || make_default_callback(task)
      ffi_delegate = Zactor.new(@callback, _args = nil)
      attach_ffi_delegate(ffi_delegate)
    end

    # Same as {SendReceiveMethods#<<}, but raises if actor is terminated.
    # @param message [Object] message to send to the actor, see {Message.coerce}
    # @return [self]
    # @raise [DeadActorError] if actor is terminated
    def <<(message)
      raise DeadActorError if not @running
      @ptr_mtx.synchronize do
        super
      end
      self
    end

    # Tells the actor to terminate and waits for it.
    # @return [void]
    # @raise [DeadActorError] if actor is already terminated
    def terminate
      @state_mtx.synchronize do
        raise DeadActorError if not @running
        self << "$TERM"
        @running = false
      end
      wait
    end

    # @return [Boolean] whether this actor has been terminated
    def terminated?
      @state_mtx.synchronize do
        !@running
      end
    end

    private

    # Waits for a signal from the backend pipe.
    # @return [void]
    def wait
      @ptr_mtx.synchronize do
        super
      end
    end

    # Creates a new general purpose callback. Signals the low-level actor that
    # it's ready to process messages and then calls {#process_messages}.
    #
    # @param task [Proc] the user-defined block which is passed to
    #   {#process_messages}
    # @return [FFI::Function] the callback function for the low-level actor
    # @raise [ArgumentError] if no task is given
    def make_default_callback(task)
      raise ArgumentError, "no task given" if not task
      Zactor.fn do |pipe_delegate, _args|
        begin
          @pipe = Socket::PAIR.from_ffi_delegate(pipe_delegate)
          @pipe.signal # handshake, so zactor_new() returns
          process_messages(&task)
        rescue
          p $!
          # TODO: store it?
        ensure
          @state_mtx.synchronize do
            @running = false
          end
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
    # @yieldparam message [Message] message (e.g. command) received
    # @yieldparam pipe [Socket::PAIR] pipe to write back something into the actor
    def process_messages
      while true
        begin
          message = next_message
        rescue Interrupt
          break
        end

        if "$TERM" == message.frames.first.to_s
          # NOTE: No explicit signal needed. A dying actor sends signal 0.
          break
        end

        yield message, @pipe
      end
    end

    # Receives the next message even across any interrupts.
    # @return [Message] the next message
    def next_message
      @pipe.receive
    end
  end
end
