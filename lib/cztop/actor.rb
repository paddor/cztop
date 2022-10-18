# frozen_string_literal: true

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
  # Actors should be terminated explicitly, either by calling {#terminate}
  # from the current process or sending them the "$TERM" command (from
  # outside). Not terminating them explicitly might make the process block at
  # exit.
  #
  # @example Simple Actor with Ruby block
  #   result = ""
  #   a = CZTop::Actor.new do |msg, pipe|
  #     case msg[0]
  #     when "foo"
  #       pipe << "bar"
  #     when "append"
  #       result << msg[1].to_s
  #     when "result"
  #       pipe << result
  #     end
  #   end
  #   a.request("foo")[0] #=> "bar"
  #   a.request("foo")[0] #=> "bar"
  #   a << ["append", "baz"] << ["append", "baz"]
  #   a.request("result")[0] #=> "bazbaz"
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


    # @return [Exception] the exception that crashed this actor, if any
    attr_reader :exception


    # Creates a new actor. Either pass a callback directly or a block. The
    # block will be called for every received message.
    #
    # In case the given callback is an FFI::Pointer (to a C function), it's
    # used as-is. It is expected to do the handshake (signal) itself.
    #
    # @param callback [FFI::Pointer, Proc, #call] pointer to a C function or
    #   just anything callable
    # @param c_args [FFI::Pointer, nil] args, only useful if callback is an
    #   FFI::Pointer
    # @yieldparam message [Message]
    # @yieldparam pipe [Socket::PAIR]
    # @see #process_messages
    def initialize(callback = nil, c_args = nil, &handler)
      @running         = true
      @mtx             = Mutex.new
      @callback        = callback || handler
      @callback        = shim(@callback) unless @callback.is_a? ::FFI::Pointer
      ffi_delegate     = Zactor.new(@callback, c_args)
      attach_ffi_delegate(ffi_delegate)
      options.sndtimeo = 20 # ms # see #<<
    end


    # Send a message to the actor.
    # @param message [Object] message to send to the actor, see {Message.coerce}
    # @return [self] so it's chainable
    # @raise [DeadActorError] if actor is terminated
    # @raise [IO::EAGAINWaitWritable, RuntimeError] anything that could be
    #   raised by {Message#send_to}
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
        begin
          @mtx.synchronize do
            raise DeadActorError unless @running

            message.send_to(self)
          end
        rescue IO::EAGAINWaitWritable
          # The sndtimeo has been reached.
          #
          # This should fix the race condition (mainly on JRuby) between
          # @running not being set to false yet but the actor handler already
          # terminating and thus not able to receive messages anymore.
          #
          # This shouldn't result in an infinite loop, since it'll stop as
          # soon as @running is set to false by #signal_shimmed_handler_death,
          # at least when using a Ruby handler.
          #
          # In case of a C function handler, it MUST NOT crash and only
          # terminate when being sent the "$TERM" message using #terminate (so
          # #await_handler_death can set
          # @running to false).
          retry
        end
      end

      self
    end


    # Receive a message from the actor.
    # @return [Message]
    # @raise [DeadActorError] if actor is terminated
    def receive
      @mtx.synchronize do
        raise DeadActorError unless @running

        super
      end
    end


    # Same as {#<<}, but also waits for a response from the actor and returns
    # it.
    # @param message [Message] the request to the actor
    # @return [Message] the actor's response
    # @raise [ArgumentError] if the message is "$TERM" (use {#terminate})
    def request(message)
      @mtx.synchronize do
        raise DeadActorError unless @running

        message = Message.coerce(message)
        raise ArgumentError, 'use #terminate' if TERM == message[0]

        message.send_to(self)
        Message.receive_from(self)
      end
    rescue IO::EAGAINWaitWritable
      # same as in #<<
      retry
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
      @mtx.synchronize do
        raise DeadActorError unless @running

        Zsock.send(ffi_delegate, picture, *args)
      end
    end


    # Thread-safe {PolymorphicZsockMethods#wait}.
    # @return [Integer]
    def wait
      @mtx.synchronize do
        super
      end
    end


    # Tells the actor to terminate and waits for it. Idempotent.
    # @return [Boolean] whether it died just now (+false+ if it was dead
    #   already)
    def terminate
      @mtx.synchronize do
        return false unless @running

        Message.new(TERM).send_to(self)
        await_handler_death
        true
      end
    rescue IO::EAGAINWaitWritable
      # same as in #<<
      retry
    end


    # @return [Boolean] whether this actor is dead (terminated or crashed)
    def dead?
      !@running
    end


    # @return [Boolean] whether this actor has crashed
    # @see #exception
    def crashed?
      !!@exception # if set, it has crashed
    end


    private


    # Shims the given handler. The shim is used to do the handshake, to
    # {#process_messages}, and ensure we're notified when the handler has
    # terminated.
    #
    # @param handler [Proc, #call] the handler used to process messages
    # @return [FFI::Function] the callback function to be passed to the zactor
    # @raise [ArgumentError] if invalid handler given
    def shim(handler)
      raise ArgumentError, 'invalid handler' unless handler.respond_to?(:call)

      @handler_thread      = nil
      @handler_dead_signal = Queue.new # used for signaling

      Zactor.fn do |pipe_delegate, _args|
        @mtx.synchronize do
          @handler_thread = Thread.current
          @pipe           = Socket::PAIR.from_ffi_delegate(pipe_delegate)
          @pipe.signal # handshake, so zactor_new() returns
        end

        process_messages(handler)
      rescue Exception
        @exception = $ERROR_INFO
      ensure
        signal_shimmed_handler_death
      end
    end


    # @return [Boolean] whether the handler is a Ruby object, like a simple
    #   block (as opposed to a FFI::Pointer to a C function)
    def handler_shimmed?
      !!@handler_thread # if it exists, it's shimmed
    end


    # the command which causes an actor handler to terminate
    TERM = '$TERM'


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
    # @yieldparam pipe [Socket::PAIR] pipe to write back something into the
    #   actor
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
    def signal_shimmed_handler_death
      # NOTE: can't just use ConditionVariable, as the signaling code might be
      # run BEFORE the waiting code.

      Thread.new do
        @handler_thread.join

        # NOTE: we do this here and not in #terminate, so it also works when
        # actor isn't terminated using #terminate
        @running = false

        @handler_dead_signal.push(nil)
      end
    end


    # Waits for the C or Ruby handler to die.
    # @return [void]
    def await_handler_death
      if handler_shimmed?
        # for Ruby block/Proc object handlers
        @handler_dead_signal.pop

      else
        # for handlers that are passed as C functions, we rely on normal death
        # signal

        # can't use #wait here because of recursive deadlock
        Zsock.wait(ffi_delegate)

        @running = false
      end
    end

  end
end
