module CZTop

  # Authentication for ZeroMQ security mechanisms.
  #
  # This is implemented using an {Actor}.
  #
  # @see http://api.zeromq.org/czmq3-0:zauth
  class Authenticator
    def allow(*addrs)
      # TODO
    end
    def deny(*addrs)
      # TODO
    end
    ANY_CERTIFICATE = "*"
    def use_curve(directory = ANY_CERTIFICATE)
      # TODO
    end
  end
end
