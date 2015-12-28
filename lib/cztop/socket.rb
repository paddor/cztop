module CZTop
  # Represents a CZMQ::FFI::Zsock.
  class Socket
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ZsockOptions
    include SendReceiveMethods
    include PolymorphicZsockMethods

    # Used for various errors.
    class Error < RuntimeError; end

    # @!group CURVE Security

    # Enables CURVE security and makes this socket a CURVE server.
    # @param server_certificate [Certificate] the (local) server's public key,
    #   so remote client sockets are able to authenticate this server
    # @param domain [String] domain used in authentication
    def make_secure_server(server_certificate, domain)
      # TODO
    end

    # Enables CURVE security and makes this socket a CURVE client.
    # @param client_certificate [Certificate] the (local) client's key (public
    #   and secret), to secure communication and possibly be authenticated by
    #   the server
    # @param server_certificate [Certificate] the remote server's public key,
    #   so this socket is able to authenticate the server
    # @param domain [String] domain used in authentication
    def make_secure_client(client_certificate = Certificate.new,
                           server_certificate, domain)
      # TODO
    end

    # @!endgroup

    # @return [String] last bound endpoint, if any
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
    # @raise [ArgumentError] if the endpoint is incorrect
    def disconnect(endpoint)
      rc = ffi_delegate.disconnect("%s", :string, endpoint)
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
      rc = ffi_delegate.bind("%s", :string, endpoint)
      raise Error, "unable to bind to %p" % endpoint if rc == -1
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
  end
end
