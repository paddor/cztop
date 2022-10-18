# frozen_string_literal: true

module CZTop
  # This module provides two classes useful when implementing your own ZAP
  # authentication handler or when directly communicating with one. Within
  # CZTop, it's merely used for testing.
  #
  # Some of the features:
  # * useful for both sides of the ZAP communication, i.e. useful for testing
  # * security mechanism agnostic
  # * protocol errors, version mismatches, and internal errors as exceptions
  # * useful to implement your own ZAP handler
  #
  # @note This is not needed to be able to use {CZTop::Authenticator}!
  # @see https://rfc.zeromq.org/spec:27/ZAP
  module ZAP

    # the endpoint a ZAP authenticator has bound to
    ENDPOINT = 'inproc://zeromq.zap.01'

    # the ZAP version supported by this code
    VERSION = '1.0'

    # superclass for ZAP errors
    class Error < StandardError
    end


    # used when the response contains an unsupported version
    class VersionMismatch < Error
    end


    # security mechanisms mentioned in ZeroMQ RFC 27.
    module Mechanisms

      NULL  = 'NULL'
      PLAIN = 'PLAIN'
      CURVE = 'CURVE'

    end


    # Represents a ZAP request.
    class Request

      # Crafts a new {Request} from a message.
      #
      # @param msg [CZTop::message] the message
      # @return [Request] the request
      # @raise [VersionMismatch] if the message contains an unsupported version
      def self.from_message(msg)
        version,       # The version frame, which SHALL contain the three octets "1.0".
        request_id,    # The request id, which MAY contain an opaque binary blob.
        domain,        # The domain, which SHALL contain a string.
        address,       # The address, the origin network IP address.
        identity,      # The identity, the connection Identity, if any.
        mechanism,     # The mechanism, which SHALL contain a string.
        *credentials = # The credentials, which SHALL be zero or more opaque frames.
          msg.to_a

        raise VersionMismatch if version != VERSION

        new(domain, credentials, mechanism: mechanism).tap do |r|
          r.version    = version
          r.request_id = request_id
          r.address    = address
          r.identity   = identity
        end
      end

      # @return [String] ZAP version
      attr_accessor :version

      # @return [String, #to_s] the authentication domain
      attr_accessor :domain

      # @return [Array<String, #to_s>] the credentials, 0 or more
      attr_accessor :credentials

      # @return [String, #to_s]
      attr_accessor :request_id

      # @return [String, #to_s]
      attr_accessor :address

      # @return [String, #to_s] the connection identity
      attr_accessor :identity

      # @see Mechanisms
      # @return [String, #to_s] the security mechanism to be used
      attr_accessor :mechanism

      # Initializes a new ZAP request. The security mechanism is set to
      # CURVE (can be changed later).
      #
      # @param domain [String] the domain within to authenticate
      # @param credentials [Array<String>] the credentials of the user,
      #   depending on the security mechanism used
      def initialize(domain, credentials = [], mechanism: Mechanisms::CURVE)
        @domain      = domain
        @credentials = credentials
        @mechanism   = mechanism
        @version     = VERSION
      end


      # Creates a sendable message from this {Request}.
      # @return [CZTop::Message} this request packed into a message
      def to_msg
        fields = [@version, @request_id, @domain, @address,
                  @identity, @mechanism, @credentials].flatten.map(&:to_s)

        CZTop::Message.new(fields)
      end

    end


    # Represents a ZAP response.
    class Response

      # used to indicate a temporary error
      class TemporaryError < Error
      end


      # used to indicate an internal error of the authenticator
      class InternalError < Error
      end


      # Status codes of ZAP responses.
      module StatusCodes

        SUCCESS                = '200'
        TEMPORARY_ERROR        = '300'
        AUTHENTICATION_FAILURE = '400'
        INTERNAL_ERROR         = '500'

        ALL = [
          SUCCESS,
          TEMPORARY_ERROR,
          AUTHENTICATION_FAILURE,
          INTERNAL_ERROR
        ].freeze

      end

      include StatusCodes

      # Crafts a new {Response} from a message.
      #
      # @param msg [CZTop::message] the message
      # @return [Response] the response
      # @raise [VersionMismatch] if the message contains an unsupported version
      # @raise [TemporaryError] if the status code indicates a temporary error
      # @raise [InternalError] if the status code indicates an internal error,
      #   or the status code is invalid
      def self.from_message(msg)
        version,     # The version frame, which SHALL contain the three octets "1.0".
        request_id,  # The request id, which MAY contain an opaque binary blob.
        status_code, # The status code, which SHALL contain a string.
        status_text, # The status text, which MAY contain a string.
        user_id,     # The user id, which SHALL contain a string.
        meta_data =  # The meta data, which MAY contain a blob.
          msg.to_a

        raise VersionMismatch if version != VERSION

        case status_code
        when SUCCESS, AUTHENTICATION_FAILURE
          # valid codes, nothing to do
        when TEMPORARY_ERROR
          raise TemporaryError, status_text
        when INTERNAL_ERROR
          raise InternalError, status_text
        else
          raise InternalError, 'invalid status code'
        end

        new(status_code).tap do |r|
          r.version     = version
          r.request_id  = request_id
          r.status_code = status_code
          r.status_text = status_text
          r.user_id     = user_id
          r.meta_data   = meta_data
        end
      end

      # @return [String] ZAP version
      attr_accessor :version

      # @return [String] the original request ID
      attr_accessor :request_id

      # @return [String] status code
      # @see StatusCodes
      attr_accessor :status_code

      # @return [String] status explanation
      attr_accessor :status_text

      # @return [String] meta data in ZMTP 3.0 format
      attr_writer :meta_data

      # @return [String] the user ID
      attr_writer :user_id

      # Initializes a new response.
      #
      # @param status_code [String, #to_s] ZAP status code
      def initialize(status_code)
        @status_code = status_code.to_s
        raise ArgumentError unless ALL.include?(@status_code)

        @version     = VERSION
      end


      # @return [Boolean] whether the authentication was successful
      def success?
        @status_code == SUCCESS
      end


      # Returns the user ID, if authentication was successful.
      # @return [String] the user ID of the authenticated user
      # @return [nil] if authentication was unsuccessful
      def user_id
        return nil unless success?

        @user_id
      end


      # Returns the meta data, if authentication was successful.
      # @return [String] the meta data for the authenticated user
      # @return [nil] if authentication was unsuccessful
      def meta_data
        return nil unless success?

        @meta_data
      end


      # Creates a sendable message from this {Response}.
      # @return [CZTop::Message} this request packed into a message
      def to_msg
        fields = [@version, @request_id, @status_code,
                  @status_text, @user_id, @meta_data].map(&:to_s)
        CZTop::Message.new(fields)
      end

    end

  end
end
