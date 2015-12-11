module CZTop
  # This module adds the ability to access options of a {Socket} or an
  # {Actor}.
  # @see http://api.zeromq.org/czmq3-0:zsock-option
  module ZsockOptions
    # Access to the options of this socket.
    # @return [Options]
    def options
      OptionsAccessor.new(self)
    end

    # Used to access the options of a {Socket} or {Actor}.
    class OptionsAccessor
      # @return [Socket, Actor] whose options this {Options} instance is
      #   accessing
      attr_reader :zocket

      # @param zocket [Socket, Actor]
      def initialize(zocket)
        @zocket = zocket
      end

      # TODO
    end
  end
end
