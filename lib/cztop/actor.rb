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
    end
  end
end
