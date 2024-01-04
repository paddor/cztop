# frozen_string_literal: true

module CZTop
  # Represents a CZMQ::FFI::Zcert.
  class Certificate

    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ::CZMQ::FFI

    unless ::CZMQ::FFI::Zsys.has_curve
      def self.new(...)
        fail NotImplementedError
      end
    end


    # Warns if CURVE security isn't available.
    # @return [void]
    def self.check_curve_availability
      return if Zsys.has_curve

      warn "CZTop: CURVE isn't available. Consider installing libsodium."
    end


    # Loads a certificate from a file.
    # @param filename [String, Pathname, #to_s] path to certificate file
    # @return [Certificate] the loaded certificate
    def self.load(filename)
      ptr = Zcert.load(filename.to_s)
      from_ffi_delegate(ptr)
    end


    # Creates a new certificate from the given keys (either binary or in Z85
    # format).
    # @param public_key [String] binary public key (32 or 40 bytes)
    # @param secret_key [String, nil] binary secret key (32 or 40 bytes), or
    #   nil to initialize a public key only certificate
    # @return [Certificate] the fresh certificate
    # @raise [ArgumentError] if keys passed are invalid
    # @raise [SystemCallError] if this fails
    def self.new_from(public_key, secret_key = nil)
      raise ArgumentError, 'no public key given' unless public_key

      secret_key ||= "\x00" * 32 # no secret key given, provide 32 null bytes

      # convert Z85 => binary
      public_key = Z85.decode(public_key) if public_key.bytesize == 40
      secret_key = Z85.decode(secret_key) if secret_key.bytesize == 40

      raise ArgumentError, 'invalid public key size' if public_key.bytesize != 32
      raise ArgumentError, 'invalid secret key size' if secret_key.bytesize != 32

      ptr = Zcert.new_from(public_key, secret_key)
      from_ffi_delegate(ptr)
    end


    # Initialize a new in-memory certificate with random keys.
    def initialize
      attach_ffi_delegate(Zcert.new)
    end


    KEY_ALL_ZERO = '0000000000000000000000000000000000000000'

    # @return [Boolean] whether one of the keys is all zeros (happens when CURVE is not available, i.e. libzmq was
    #   compiled without libsodium)
    # @see .check_curve_availability
    def zero?
      public_key(format: :z85) == KEY_ALL_ZERO || secret_key(format: :z85) == KEY_ALL_ZERO
    end


    # Returns the public key either as Z85-encoded ASCII string (default) or
    # binary string.
    # @param format [Symbol] +:z85+ for Z85, +:binary+ for binary
    # @return [String] public key
    def public_key(format: :z85)
      case format
      when :z85
        ffi_delegate.public_txt.force_encoding(Encoding::ASCII)
      when :binary
        ffi_delegate.public_key.read_string(32)
      else
        raise ArgumentError, format('invalid format: %p', format)
      end
    end


    # Returns the secret key either as Z85-encoded ASCII string (default) or
    # binary string.
    # @param format [Symbol] +:z85+ for Z85, +:binary+ for binary
    # @return [String] secret key
    # @return [nil] if secret key is undefined (like after loading from a file
    #   created using {#save_public})
    def secret_key(format: :z85)
      case format
      when :z85
        key = ffi_delegate.secret_txt.force_encoding(Encoding::ASCII)
        return nil if key.count('0') == 40
      when :binary
        key = ffi_delegate.secret_key.read_string(32)
        return nil if key.count("\0") == 32
      else
        raise ArgumentError, format('invalid format: %p', format)
      end
      key
    end


    # Get metadata.
    # @param key [String] metadata key
    # @return [String] value for meta key
    # @return [nil] if metadata key is not set
    def [](key)
      ffi_delegate.meta(key)
    end


    # Set metadata.
    # @param key [String] metadata key
    # @param value [String] metadata value
    # @return [value]
    def []=(key, value)
      if value
        ffi_delegate.set_meta(key, '%s', :string, value)
      else
        ffi_delegate.unset_meta(key)
      end
    end


    # Returns meta keys set.
    # @return [Array<String>]
    def meta_keys
      zlist     = ffi_delegate.meta_keys
      first_key = zlist.first
      return [] if first_key.null?

      keys = [first_key.read_string]
      while (key = zlist.next)
        break if key.null?

        keys << key.read_string
      end
      keys
    end


    # Save full certificate (public + secret) to files.
    # @param filename [String, #to_s] path/filename to public file
    # @return [void]
    # @raise [ArgumentError] if path is invalid
    # @raise [SystemCallError] if this fails
    # @note This will create two files: one of the public key and one for the
    #   secret key. The secret filename is filename + "_secret".
    def save(filename)
      # see https://github.com/zeromq/czmq/issues/1244
      raise ArgumentError, "filename can't be empty" if filename.to_s.empty?

      rc = ffi_delegate.save(filename.to_s)
      return if rc.zero?

      raise_zmq_err(format('error while saving to file %p', filename))
    end


    # Saves the public key to file in ZPL ({Config}) format.
    # @param filename [String, #to_s] path/filename to public file
    # @return [void]
    # @raise [SystemCallError] if this fails
    def save_public(filename)
      rc = ffi_delegate.save_public(filename.to_s)
      return if rc.zero?

      raise_zmq_err(format('error while saving to the file %p', filename))
    end


    # Saves the secret key to file in ZPL ({Config}) format.
    # @param filename [String, #to_s] path/filename to secret file
    # @return [void]
    # @raise [SystemCallError] if this fails
    def save_secret(filename)
      rc = ffi_delegate.save_secret(filename.to_s)
      return if rc.zero?

      raise_zmq_err(format('error while saving to the file %p', filename))
    end


    # Applies this certificate on a {Socket} or {Actor}.
    # @param zocket [Socket, Actor] path/filename to secret file
    # @return [void]
    # @raise [SystemCallError] if secret key is undefined
    def apply(zocket)
      raise ArgumentError, format('invalid zocket argument %p', zocket) unless zocket
      return ffi_delegate.apply(zocket) unless secret_key.nil?

      raise_zmq_err('secret key is undefined')
    end


    # Duplicates the certificate.
    # @return [Certificate]
    # @raise [SystemCallError] if this fails
    def dup
      ptr = ffi_delegate.dup
      return from_ffi_delegate(ptr) unless ptr.null?

      raise_zmq_err('unable to duplicate certificate')
    end


    # Compares this certificate to another.
    # @param other [Cert] other certificate
    # @return [Boolean] whether they have the same keys
    def ==(other)
      ffi_delegate.eq(other.ffi_delegate)
    end

  end
end
