# frozen_string_literal: true

module CZTop
  # Authentication for ZeroMQ security mechanisms.
  #
  # This is implemented using an {Actor}.
  #
  # @see http://api.zeromq.org/czmq3-0:zauth
  class Authenticator
    include ::CZMQ::FFI

    # function pointer to the +zauth()+ function
    ZAUTH_FPTR = ::CZMQ::FFI.ffi_libraries.each do |dl|
      fptr = dl.find_function('zauth')
      break fptr if fptr
    end
    raise LoadError, "couldn't find zauth()" if ZAUTH_FPTR.nil?

    # This installs authentication on all {Socket}s and {Actor}s. Until you
    # add policies, all incoming _NULL_ connections are allowed,
    # and all _PLAIN_ and _CURVE_ connections are denied.
    #
    # @param cert_store [CertStore] a custom certificate store
    def initialize(cert_store = nil)
      if cert_store
        raise ArgumentError unless cert_store.is_a?(CertStore)

        cert_store = cert_store.ffi_delegate
        cert_store.__undef_finalizer # native object is now owned by zauth() actor
      end
      @actor = Actor.new(ZAUTH_FPTR, cert_store)
    end

    # @return [Actor] the actor behind this authenticator
    attr_reader :actor

    # Terminates the authenticator.
    # @return [void]
    def terminate
      @actor.terminate
    end


    # Enable verbose logging of commands and activity.
    # @return [void]
    def verbose!
      @actor << 'VERBOSE'
      @actor.wait
    end


    # Add a list of IP addresses to the whitelist. For _NULL_, all clients
    # from these addresses will be accepted. For _PLAIN_ and _CURVE_, they
    # will be allowed to continue with authentication.
    #
    # @param addrs [String] IP address(es) to allow
    # @return [void]
    def allow(*addrs)
      @actor << ['ALLOW', *addrs]
      @actor.wait
    end


    # Add a list of IP addresses to the blacklist. For all security
    # mechanisms, this rejects the connection without any further
    # authentication. Use either a whitelist, or a blacklist, not not both. If
    # you define both a whitelist and a blacklist, only the whitelist takes
    # effect.
    #
    # @param addrs [String] IP address(es) to deny
    # @return [void]
    def deny(*addrs)
      @actor << ['DENY', *addrs]
      @actor.wait
    end


    # Configure PLAIN security mechanism using a plain-text password file. The
    # password file will be reloaded automatically if modified externally.
    #
    # @param filename [String] path to the password file
    # @return [void]
    def plain(filename)
      @actor << ['PLAIN', *filename]
      @actor.wait
    end

    # used to allow any CURVE client
    ALLOW_ANY = '*'

    # Configure CURVE authentication, using a directory that holds all public
    # client certificates, i.e. their public keys. The certificates must have been
    # created using {Certificate#save}/{Certificate#save_public}. You can add
    # and remove certificates in that directory at any time.
    #
    # @param directory [String] the directory to take the keys from
    # @return [void]
    def curve(directory = ALLOW_ANY)
      @actor << ['CURVE', directory]
      @actor.wait
    end


    # Configure GSSAPI authentication.
    # @return [void]
    def gssapi
      @actor << 'GSSAPI'
      @actor.wait
    end
  end
end
