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
    def secret_key
      ffi_delegate.secret_key.read_string(KEY_BYTES)
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
    # @return [String] value for meta key
    # @return [nil] if metadata key is not set
    def [](key)
      ptr = ffi_delegate.meta(key)
      return nil if ptr.null?
      ptr.read_string
    end
    # Set metadata.
    # @return [value]
    def []=(key, value)
      if value
        ffi_delegate.set_meta(key, "%s", :string, value)
      else
        ffi_delegate.set_meta(key, nil)
      end
    end

    # Returns meta keys set.
    # @return [Array<String>]
    def meta_keys
      # TODO
    end

    # Save full certificate (public + secret) to files.
    # @param filename [String] path/filename to public file
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
    # TODO
    def save_public(filename)
    end
    # TODO
    def save_secret(filename)
    end
    # TODO
    def apply(zocket)
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
    # @return [Boolean] whether they have the same keys
    def ==(other)
      ffi_delegate.eq(other.ffi_delegate)
    end
  end
end
