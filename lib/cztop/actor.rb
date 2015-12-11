module CZTop
  # @note Mainly because Proxy and Authenticator are actors.
  class Actor
    # @!parse extend CZTop::HasFFIDelegate::ClassMethods


    include HasFFIDelegate
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
