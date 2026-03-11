# frozen_string_literal: true

module CZTop
  # Represents a CZMQ::FFI::Zsock.
  class Socket

    include HasFFIDelegate
    extend HasFFIDelegate::ClassMethods
    include ZsockOptions
    include PolymorphicZsockMethods
    include CZMQ::FFI


    # @param type [Symbol, Integer] type from {Types} or like +:PUB+
    # @return [REQ, REP, PUSH, PULL, ... ] the new socket
    # @see Types
    # @example Creating a socket by providing its type as a parameter
    #   my_sock = CZTop::Socket.new_by_type(:DEALER, "tcp://example.com:4000")
    def self.new_by_type(type)
      case type
      when Integer
        type_code  = type
        type_name  = TypeNames[type_code] or
          raise ArgumentError, format('invalid type %p', type)
        type_class = Socket.const_get(type_name)
      when Symbol
        type_code  = Types.const_get(type)
        type_class = Socket.const_get(type)
      else
        raise ArgumentError, format('invalid socket type: %p', type)
      end
      ffi_delegate = Zsock.new(type_code)
      sock         = type_class.allocate
      sock.attach_ffi_delegate(ffi_delegate)
      sock
    end


    def initialize(endpoints = nil); end


    # @return [String] last bound endpoint, if any
    # @return [nil] if not bound
    def last_endpoint
      ffi_delegate.endpoint
    end


    # Connects to an endpoint.
    # @param endpoint [String]
    # @return [void]
    # @raise [ArgumentError] if the endpoint is incorrect
    def connect(endpoint)
      rc = ffi_delegate.connect('%s', :string, endpoint)
      raise ArgumentError, format('incorrect endpoint: %p', endpoint) if rc == -1
    end


    # Disconnects from an endpoint.
    # @param endpoint [String]
    # @return [void]
    # @raise [ArgumentError] if the endpoint is incorrect
    def disconnect(endpoint)
      rc = ffi_delegate.disconnect('%s', :string, endpoint)
      raise ArgumentError, format('incorrect endpoint: %p', endpoint) if rc == -1
    end


    # Closes and destroys the native socket.
    # @return [void]
    # @note Don't try to use it anymore afterwards.
    def close
      ffi_delegate.destroy
    end

    # @return [Integer] last automatically selected, bound TCP port, if any
    # @return [nil] if not bound to a TCP port yet
    attr_reader :last_tcp_port

    # Binds to an endpoint.
    # @note When binding to an automatically selected TCP port, this will set
    #   {#last_tcp_port}.
    # @param endpoint [String]
    # @return [void]
    # @raise [SystemCallError] in case of failure
    def bind(endpoint)
      rc = ffi_delegate.bind('%s', :string, endpoint)
      raise_zmq_err(format('unable to bind to %p', endpoint)) if rc == -1
      @last_tcp_port = rc if rc.positive?
    end


    # Unbinds from an endpoint.
    # @param endpoint [String]
    # @return [void]
    # @raise [ArgumentError] if the endpoint is incorrect
    def unbind(endpoint)
      rc = ffi_delegate.unbind('%s', :string, endpoint)
      raise ArgumentError, format('incorrect endpoint: %p', endpoint) if rc == -1
    end


    # Inspects this {Socket}.
    # @return [String] shows class, native address, and {#last_endpoint}
    def inspect
      format('#<%s:0x%x last_endpoint=%p>', self.class, to_ptr.address, last_endpoint)
    rescue Zsock::DestroyedError
      format('#<%s: invalid>', self.class)
    end

  end
end
