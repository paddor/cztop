module CZTop
  # Represents a CZMQ::FFI::Zsock.
  class Socket
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ZsockOptions
    include SendReceiveMethods
    include PolymorphicZsockMethods
    include CZMQ::FFI

    # @!group CURVE Security

    # Enables CURVE security and makes this socket a CURVE server.
    # @param cert [Certificate] this server's certificate,
    #   so remote clients are able to authenticate this server
    # @note You'll have to use a {CZTop::Authenticator}.
    # @return [void]
    def CURVE_server!(cert)
      options.CURVE_server = true
      cert.apply(self) # NOTE: desired: raises if no secret key in cert
    end

    # Enables CURVE security and makes this socket a CURVE client.
    # @param client_cert [Certificate] client's certificate, to secure
    #   communication (and be authenticated by the server)
    # @param server_cert [Certificate] the remote server's certificate, so
    #   this socket is able to authenticate the server
    # @return [void]
    # @raise [SecurityError] if the server's secret key is set in server_cert,
    #   which means it's not secret anymore
    # @raise [SystemCallError] if there's no secret key in client_cert
    def CURVE_client!(client_cert, server_cert)
      if server_cert.secret_key
        raise SecurityError, "server's secret key not secret"
      end

      client_cert.apply(self) # NOTE: desired: raises if no secret key in cert
      options.CURVE_serverkey = server_cert.public_key
    end

    # @!endgroup

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
      rc = ffi_delegate.connect("%s", :string, endpoint)
      raise ArgumentError, "incorrect endpoint: %p" % endpoint if rc == -1
    end

    # Disconnects from an endpoint.
    # @param endpoint [String]
    # @return [void]
    # @raise [ArgumentError] if the endpoint is incorrect
    def disconnect(endpoint)
      rc = ffi_delegate.disconnect("%s", :string, endpoint)
      raise ArgumentError, "incorrect endpoint: %p" % endpoint if rc == -1
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
      rc = ffi_delegate.bind("%s", :string, endpoint)
      raise_zmq_err("unable to bind to %p" % endpoint) if rc == -1
      @last_tcp_port = rc if rc > 0
    end

    # Unbinds from an endpoint.
    # @param endpoint [String]
    # @return [void]
    # @raise [ArgumentError] if the endpoint is incorrect
    def unbind(endpoint)
      rc = ffi_delegate.unbind("%s", :string, endpoint)
      raise ArgumentError, "incorrect endpoint: %p" % endpoint if rc == -1
    end

    # Inspects this {Socket}.
    # @return [String] shows class, native address, and {#last_endpoint}
    def inspect
      "#<%s:0x%x last_endpoint=%p>" % [
        self.class,
        to_ptr.address,
        last_endpoint
      ]
    end
  end
end
