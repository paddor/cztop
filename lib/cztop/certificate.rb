module CZTop
  # Represents a CZMQ::FFI::Zcert.
  class Certificate
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ::CZMQ::FFI

    # various errors around {Certificate}s
    class Error < RuntimeError; end

    # Loads a certificate from a file.
    # @param filename [String, Pathname, #to_s] path to certificate file
    # @return [Certificate] the loaded certificate
    def self.load(filename)
      ptr = Zcert.load(filename.to_s)
      from_ffi_delegate(ptr)
    end

    # Creates a new certificate from the given keys.
    # @param public_key [String] binary public key
    # @param secret_key [String] binary secret key
    # @return [Certificate] the fresh certificate
    def self.new_from(public_key, secret_key)
      raise Error, "no public key given" unless public_key
      raise Error, "no secret key given" unless secret_key

      raise Error, "invalid public key size" if public_key.bytesize!=KEY_BYTES
      raise Error, "invalid secret key size" if secret_key.bytesize!=KEY_BYTES

      ptr = Zcert.new_from(public_key, secret_key)
      raise Error if ptr.null?
      from_ffi_delegate(ptr)
    end

    # Initialize a new in-memory certificate with random keys.
    def initialize
      attach_ffi_delegate(Zcert.new)
    end

    # length of a binary key in bytes
    KEY_BYTES = 32

    # Returns the public key in binary form.
    # @return [String] binary public key
    def public_key
      ffi_delegate.public_key.read_string(KEY_BYTES)
    end

    # Returns the secret key in binary form.
    # @return [String] binary secret key
    # @return [nil] if secret key is undefined (like after loading from a file
    #   created using {#save_public})
    def secret_key
      key = ffi_delegate.secret_key.read_string(KEY_BYTES)
      return nil if key.count("\0") == KEY_BYTES
      key
    end

    # Returns the public key in Z85 form.
    # @return [String] Z85-encoded public key
    def public_key_txt
      ffi_delegate.public_txt.read_string.force_encoding(Encoding::ASCII)
    end
    # Returns the secret key in Z85 form.
    # @return [String] Z85-encoded secret key
    def secret_key_txt
      ffi_delegate.secret_txt.read_string.force_encoding(Encoding::ASCII)
    end

    # Get metadata.
    # @param key [String] metadata key
    # @return [String] value for meta key
    # @return [nil] if metadata key is not set
    def [](key)
      ptr = ffi_delegate.meta(key)
      return nil if ptr.null?
      ptr.read_string
    end
    # Set metadata.
    # @param key [String] metadata key
    # @param value [String] metadata value
    # @return [value]
    def []=(key, value)
      if value
        ffi_delegate.set_meta(key, "%s", :string, value)
      else
        ffi_delegate.unset_meta(key)
      end
    end

    # Returns meta keys set.
    # @return [Array<String>]
    def meta_keys
      zlist = ffi_delegate.meta_keys
      first_key = zlist.first
      return [] if first_key.null?
      keys = [first_key.read_string]
      while key = zlist.next
        break if key.null?
        keys << key.read_string
      end
      keys
    end

    # Save full certificate (public + secret) to files.
    # @param filename [String, #to_s] path/filename to public file
    # @return [void]
    # @raise [Error] if this fails
    # @note This will create two files: one of the public key and one for the
    #   secret key. The secret filename is filename + "_secret".
    def save(filename)
      # see https://github.com/zeromq/czmq/issues/1244
      raise Error, "filename can't be empty" if filename.to_s.empty?
      rc = ffi_delegate.save(filename.to_s)
      raise Error, "error while saving to file %p" % filename if rc == -1
    end

    # Saves the public key to file in ZPL ({Config}) format.
    # @param filename [String, #to_s] path/filename to public file
    # @return [void]
    # @raise [Error] if this fails
    def save_public(filename)
      rc = ffi_delegate.save_public(filename.to_s)
      raise Error, "error while saving to the file %p" % filename if rc == -1
    end

    # Saves the secret key to file in ZPL ({Config}) format.
    # @param filename [String, #to_s] path/filename to secret file
    # @return [void]
    # @raise [Error] if this fails
    def save_secret(filename)
      rc = ffi_delegate.save_secret(filename.to_s)
      raise Error, "error while saving to the file %p" % filename if rc == -1
    end

    # Applies this certificate on a {Socket} or {Actor}.
    # @param zocket [Socket, Actor] path/filename to secret file
    # @return [void]
    # @raises [Error] if secret key is undefined
    def apply(zocket)
      raise Error, "secret key is undefined" if secret_key.nil?
      ffi_delegate.apply(zocket)
    end

    # Duplicates the certificate.
    # @return [Certificate]
    # @raise [Error] if this fails
    def dup
      ptr = ffi_delegate.dup
      raise Error, "unable to duplicate certificate" if ptr.null?
      from_ffi_delegate(ptr)
    end

    # Compares this certificate to another.
    # @param other [Cert] other certificate
    # @return [Boolean] whether they have the same keys
    def ==(other)
      ffi_delegate.eq(other.ffi_delegate)
    end
  end
end
