# frozen_string_literal: true

require 'set'

module CZTop
  # A store for CURVE security certificates, either backed by files on disk or
  # in-memory.
  #
  # @see http://api.zeromq.org/czmq3-0:zcertstore
  class CertStore
    include ::CZMQ::FFI
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods

    # Initializes a new certificate store.
    #
    # @param location [String, #to_s, nil] location the path to the
    #   directories to load certificates from, or nil if no certificates need
    #   to be loaded from the disk
    def initialize(location = nil)
      location = location.to_s if location
      attach_ffi_delegate(Zcertstore.new(location))
    end


    # Looks up a certificate in the store by its public key.
    #
    # @param pubkey [String] the public key in question, in Z85 format
    # @return [Certificate] the matching certificate, if found
    # @return [nil] if no matching certificate was found
    def lookup(pubkey)
      ptr = ffi_delegate.lookup(pubkey)
      return nil if ptr.null?

      Certificate.from_ffi_delegate(ptr)
    end


    # Inserts a new certificate into the store.
    #
    # @note The same public key must not be inserted more than once.
    # @param cert [Certificate] the certificate to insert
    # @return [void]
    # @raise [ArgumentError] if the given certificate is not a Certificate
    #   object or has been inserted before already
    def insert(cert)
      raise ArgumentError unless cert.is_a?(Certificate)

      @_inserted_pubkeys ||= Set.new
      pubkey               = cert.public_key
      raise ArgumentError if @_inserted_pubkeys.include? pubkey

      ffi_delegate.insert(cert.ffi_delegate)
      @_inserted_pubkeys << pubkey
    end
  end
end
