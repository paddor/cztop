# frozen_string_literal: true

module CZTop
  # Represents a CZMQ::FFI::Zsock.
  #
  class Socket

    include HasFFIDelegate
    extend HasFFIDelegate::ClassMethods
    include ZsockOptions
    include CZMQ::FFI


    # Creates a new socket and binds it to the given endpoint.
    # @param endpoint [String] endpoint to bind to
    # @param opts [Hash] keyword arguments forwarded to {#initialize}
    #   (e.g. +curve:+, +prefix:+ for SUB)
    # @return [Socket] the new, bound socket
    #
    def self.bind(endpoint, **opts)
      new(nil, **opts).tap { |s| s.bind(endpoint) }
    end


    # Creates a new socket and connects it to the given endpoint.
    # @param endpoint [String] endpoint to connect to
    # @param opts [Hash] keyword arguments forwarded to {#initialize}
    #   (e.g. +curve:+, +prefix:+ for SUB)
    # @return [Socket] the new, connected socket
    #
    def self.connect(endpoint, **opts)
      new(nil, **opts).tap { |s| s.connect(endpoint) }
    end


    def initialize(endpoints = nil, curve: nil, linger: 0); end


    # @return [String] last bound endpoint, if any
    # @return [nil] if not bound
    #
    def last_endpoint
      ffi_delegate.endpoint
    end


    # Connects to an endpoint.
    # @param endpoint [String]
    # @return [void]
    # @raise [ArgumentError] if the endpoint is incorrect
    #
    def connect(endpoint)
      rc = ffi_delegate.connect('%s', :string, endpoint)
      raise ArgumentError, format('incorrect endpoint: %p', endpoint) if rc == -1
    end


    # Disconnects from an endpoint.
    # @param endpoint [String]
    # @return [void]
    # @raise [ArgumentError] if the endpoint is incorrect
    #
    def disconnect(endpoint)
      rc = ffi_delegate.disconnect('%s', :string, endpoint)
      raise ArgumentError, format('incorrect endpoint: %p', endpoint) if rc == -1
    end


    # Closes and destroys the native socket.
    # @return [void]
    # @note Don't try to use it anymore afterwards.
    #
    def close
      ffi_delegate.destroy
    end

    # @return [Integer] last automatically selected, bound TCP port, if any
    # @return [nil] if not bound to a TCP port yet
    #
    attr_reader :last_tcp_port

    # Binds to an endpoint.
    # @note When binding to an automatically selected TCP port, this will set
    #   {#last_tcp_port}.
    # @param endpoint [String]
    # @return [void]
    # @raise [SystemCallError] in case of failure
    #
    def bind(endpoint)
      rc = ffi_delegate.bind('%s', :string, endpoint)
      raise_zmq_err(format('unable to bind to %p', endpoint)) if rc == -1
      @last_tcp_port = rc if rc.positive?
    end


    # Unbinds from an endpoint.
    # @param endpoint [String]
    # @return [void]
    # @raise [ArgumentError] if the endpoint is incorrect
    #
    def unbind(endpoint)
      rc = ffi_delegate.unbind('%s', :string, endpoint)
      raise ArgumentError, format('incorrect endpoint: %p', endpoint) if rc == -1
    end


    # Set socket to use unbounded pipes (HWM=0); use this in cases when you are
    # totally certain the message volume can fit in memory.
    #
    def set_unbounded
      ::CZMQ::FFI::Zsock.set_unbounded(ffi_delegate)
    end


    # Inspects this {Socket}.
    # @return [String] shows class, native address, and {#last_endpoint}
    #
    def inspect
      format('#<%s:0x%x last_endpoint=%p>', self.class, to_ptr.address, last_endpoint)
    rescue Zsock::DestroyedError
      format('#<%s: invalid>', self.class)
    end


    private


    # Applies CURVE encryption settings to this socket.
    # @api private
    #
    def _apply_curve(curve)
      return unless curve
      if curve[:server_key]
        CZTop::CURVE.setup_client!(self, curve[:secret_key], curve[:server_key])
      else
        CZTop::CURVE.setup_server!(self, curve[:secret_key])
      end
    end

    # Connects or binds based on CZMQ endpoint prefix convention.
    # @api private
    # @param endpoints [String] endpoint, optionally prefixed with +@+ (bind) or +>+ (connect)
    # @param default [Symbol] +:connect+ or +:bind+ — action when no prefix given
    #
    def _attach(endpoints, default:)
      return unless endpoints
      case endpoints
      when /\A@(.+)\z/
        bind($1)
      when /\A>(.+)\z/
        connect($1)
      else
        __send__(default, endpoints)
      end
    end

  end
end
