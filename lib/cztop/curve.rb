# frozen_string_literal: true

module CZTop

  # CURVE encryption utilities for ZeroMQ.
  #
  # Provides keypair generation, key derivation, and Z85 encoding/decoding.
  # CURVE options are applied to sockets via the +curve:+ keyword argument
  # in socket constructors — there are no public CURVE methods on Socket.
  #
  module CURVE

    KEY_SIZE = 32

    # Whether CURVE encryption is available in the linked libzmq.
    # @return [Boolean]
    #
    def self.available?
      CZMQ::FFI.zsys_has_curve
    end

    # Generates a new CURVE keypair.
    # @return [Array(String, String)] +[public_key, secret_key]+ as 32-byte binary strings
    # @raise [NotImplementedError] if CURVE is not available
    #
    def self.keypair
      _require_curve!
      pub_buf = ::FFI::MemoryPointer.new(:char, 41)  # Z85 is 40 chars + null
      sec_buf = ::FFI::MemoryPointer.new(:char, 41)
      rc = CZMQ::FFI.zmq_curve_keypair(pub_buf, sec_buf)
      raise 'zmq_curve_keypair failed' unless rc == 0
      [z85_decode(pub_buf.read_string), z85_decode(sec_buf.read_string)]
    end

    # Derives the public key from a secret key.
    # @param secret_key [String] 32-byte binary secret key
    # @return [String] 32-byte binary public key
    # @raise [ArgumentError] if +secret_key+ is not 32 bytes
    # @raise [NotImplementedError] if CURVE is not available
    #
    def self.public_key(secret_key)
      _require_curve!
      _check_key!(secret_key, 'secret_key')
      sec_z85 = z85_encode(secret_key)
      pub_buf = ::FFI::MemoryPointer.new(:char, 41)
      rc = CZMQ::FFI.zmq_curve_public(pub_buf, sec_z85)
      raise 'zmq_curve_public failed' unless rc == 0
      z85_decode(pub_buf.read_string)
    end

    # Encodes a binary string to Z85.
    # @param binary [String] binary data (length must be divisible by 4)
    # @return [String] Z85-encoded string
    # @raise [ArgumentError] if length is not divisible by 4
    #
    def self.z85_encode(binary)
      binary = binary.b
      raise ArgumentError, 'binary length must be divisible by 4' unless (binary.bytesize % 4).zero?
      buf = ::FFI::MemoryPointer.new(:char, binary.bytesize * 5 / 4 + 1)
      result = CZMQ::FFI.zmq_z85_encode(buf, binary, binary.bytesize)
      raise 'zmq_z85_encode failed' if result.null?
      buf.read_string
    end

    # Decodes a Z85-encoded string to binary.
    # @param z85 [String] Z85-encoded string (length must be divisible by 5)
    # @return [String] binary data
    # @raise [ArgumentError] if length is not divisible by 5
    #
    def self.z85_decode(z85)
      raise ArgumentError, 'Z85 length must be divisible by 5' unless (z85.bytesize % 5).zero?
      bin_size = z85.bytesize * 4 / 5
      buf = ::FFI::MemoryPointer.new(:char, bin_size)
      result = CZMQ::FFI.zmq_z85_decode(buf, z85)
      raise 'zmq_z85_decode failed' if result.null?
      buf.read_string(bin_size).b
    end

    # Configures a socket as a CURVE server.
    # @api private
    #
    def self.setup_server!(socket, secret_key)
      _require_curve!
      _check_key!(secret_key, 'secret_key')
      pubkey = public_key(secret_key)
      ptr = socket.to_ptr
      CZMQ::FFI.zsock_set_curve_server(ptr, 1)
      _set_key(ptr, :zsock_set_curve_publickey_bin, pubkey)
      _set_key(ptr, :zsock_set_curve_secretkey_bin, secret_key)
      CZMQ::FFI.zsock_set_zap_domain(ptr, 'global')
    end

    # Configures a socket as a CURVE client.
    # @api private
    #
    def self.setup_client!(socket, secret_key, server_pubkey)
      _require_curve!
      _check_key!(secret_key, 'secret_key')
      _check_key!(server_pubkey, 'server_key')
      pubkey = public_key(secret_key)
      ptr = socket.to_ptr
      _set_key(ptr, :zsock_set_curve_publickey_bin, pubkey)
      _set_key(ptr, :zsock_set_curve_secretkey_bin, secret_key)
      _set_key(ptr, :zsock_set_curve_serverkey_bin, server_pubkey)
    end

    class << self
      private

      def _require_curve!
        raise NotImplementedError, 'CURVE not available in this libzmq build' unless available?
      end

      def _check_key!(key, name)
        raise ArgumentError, "#{name} must be a #{KEY_SIZE}-byte binary string" unless key.is_a?(String) && key.b.bytesize == KEY_SIZE
      end

      def _set_key(ptr, method, key)
        buf = ::FFI::MemoryPointer.new(:char, KEY_SIZE)
        buf.write_string(key.b, KEY_SIZE)
        CZMQ::FFI.__send__(method, ptr, buf)
      end
    end

  end
end
