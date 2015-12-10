module CZTop
  # Represents a {CZMQ::FFI::Zsock}.
  class Socket
    # @!parse extend CZTop::HasFFIDelegate::ClassMethods


    include HasFFIDelegate

    # Used for various errors.
    class Error < RuntimeError; end

    # @return [String] last bound endpoint, if any
    def last_endpoint
      ffi_delegate.endpoint
    end

    # Sends a signal.
    # @param [Integer] signal (0-255)
    ffi_delegate :signal

    # Waits for a signal.
    # @return [Integer] the received signal
    ffi_delegate :wait

    # Sends a message.
    # @param str_or_msg [Message, String] what to send
    def send(str_or_msg)
      Message.coerce(str_or_msg).send_to(self)
    end
    alias_method :<<, :send

    # Receives a message.
    # @return [Message]
    def receive
      Message.receive_from(self)
    end

    # Connects to an endpoint.
    # @param endpoint [String]
    # @return [void]
    # @raise [ArgumentError] if the endpoint is incorrect
    def connect(endpoint)
      rc = ffi_delegate.connect(endpoint)
      raise ArgumentError, "incorrect endpoint: %p" % endpoint if rc == -1
    end

    # Disconnects from an endpoint.
    # @param endpoint [String]
    # @raise [ArgumentError] if the endpoint is incorrect
    def disconnect(endpoint)
      # we can do sprintf in Ruby
      rc = ffi_delegate.disconnect(endpoint, *nil)
      raise ArgumentError, "incorrect endpoint: %p" % endpoint if rc == -1
    end

    # @return [Integer] last automatically selected, bound TCP port, if any
    # @return [nil] if not bound to a TCP port yet
    attr_reader :last_tcp_port

    # Binds to an endpoint.
    # @note When binding to an automatically selected TCP port, this will set
    #   {#last_tcp_port}.
    # @param endpoint [String]
    # @return [void]
    # @raise [Error] in case of failure
    def bind(endpoint)
      rc = ffi_delegate.bind(endpoint)
      raise Error, "unable to bind to %p" % endpoint if rc == -1
      @last_tcp_port = rc if rc > 0
    end

    # Unbinds from an endpoint.
    # @param endpoint [String]
    # @return [void]
    # @raise [ArgumentError] if the endpoint is incorrect
    def unbind(endpoint)
      # we can do sprintf in Ruby
      rc = ffi_delegate.unbind(endpoint, *nil)
      raise ArgumentError, "incorrect endpoint: %p" % endpoint if rc == -1
    end

    # Access to the options of this socket.
    # @return [Options]
    def options
      Options.new(self)
    end

    # Sets an option by its name.
    # @param option [Symbol, String] option name like +:rcvhwm+
    # @param value [Integer, String] value, depending on the option
    def set_option(option, value)
      options.__send__(:"#{option}=", value)
    end

    # Gets an option by its name.
    # @param option [Symbol, String] option name like +:rcvhwm+
    # @return [Integer, String] value, depending on the option
    def get_option(option)
      options.__send__(option.to_sym, value)
    end

    # Used to access the options of a {Socket} or {Actor}.
    class Options
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
