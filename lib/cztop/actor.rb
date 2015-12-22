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

    class Error < RuntimeError; end

    # Raised when trying to interact with a terminated actor.
    class DeadActorError < Error; end

    # Creates a new actor. If no callback is given, it'll create a generic one
    # which will yield every received command (first frame of an arriving
    # message).
    # @param callback [FFI::Pointer]
    # @overload initialize(&task)
    #   @yieldparam command [String]
    #   @yieldparam pipe [CZMQ::FFI::Zsock]
    def initialize(callback = nil, &task)
      @callback = callback
      if !@callback
        unless @task = task
          raise ArgumentError, "no task given"
        end
      end

      attach_ffi_delegate(Zactor.new(callback(), _args = nil))
    end

    def callback
      @callback ||= Zactor.fn do |pipe_delegate, _args|

        pipe = CZTop::Socket::PAIR.from_ffi_delegate(pipe_delegate)
        pipe.signal # signal that we're ready

        running = true
        while running
          command_ptr = Zstr.recv(pipe_delegate)
          break if command_ptr.null? # interrupted
          command = command_ptr.read_string
          case command
          when "$TERM"
            running = false
            # NOTE: No explicit signal needed. A dying actor sends signal 0.
          else
            @task.call(command, pipe)
          end

          pipe_delegate.flush # flush partially read message, if any
        end
      end
    end

    # Send message to this actor.
    # @param msg [Object] message to send to the actor, see {Message.coerce}
    # @return [void]
    # @raise [DeadActorError] if actor is terminated
    def <<(msg)
      raise DeadActorError if @terminated
      Message.coerce(msg).send_to(self)
    end

    # Tells the actor to terminate and waits for it.
    # @return [void]
    # @raise [DeadActorError] if actor is already terminated
    def terminate
      raise DeadActorError if @terminated
      self << "$TERM"
      @terminated = true
      wait
    end
  end
end
