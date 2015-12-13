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

    # @param callback [FFI::Pointer]
    # @param args [FFI::Pointer]
    # @overload initialize(&task)
    #   @yieldparam command [String]
    #   @yieldparam pipe [String]
    def initialize(callback = nil, args = nil)
      # TODO
      # After initialization: call signal(pipe, 0)
      # React to "$TERM" command with destroy

      @running = true
      @callback = callback
      @callback ||= ::CZMQ::FFI::Zactor.fn do |pipe_delegate, _args|
        p pipe_delegate
        pipe = CZTop::Socket::PAIR.from_ffi_delegate(pipe) # for yielding
        p pipe
        pipe.signal # signal that we're ready
        while @running
          puts "waiting for a command to arrive ..."
          command = ::CZMQ::FFI::Zstr.recv(pipe_delegate)
          puts "got command!"
          p command
          break if command.null? # interrupted
          p command.read_string
          case command.read_string
          when "$TERM"
            puts "actor received $TERM"
            @running = false
          else
            if block_given?
              yield command, pipe
            else
              # NOTE: just for testing
              puts "actor received command: %p" % command
            end
          end
        end
      end
      attach_ffi_delegate(::CZMQ::FFI::Zactor.new(@callback, args))
    end

    # Send message to this actor.
    def <<(msg)
      puts "sending message to actor self"
      Message.coerce(msg).send_to(self)
      puts "message sent"
    end
  end
end
