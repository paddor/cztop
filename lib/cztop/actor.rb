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

    def initialize
      # TODO
      # After initialization: call signal(pipe, 0)
      # React to "$TERM" command with destroy
    end
  end
end
