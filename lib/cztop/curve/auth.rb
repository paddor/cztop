# frozen_string_literal: true

require 'set'

module CZTop
  module CURVE

    # In-memory ZAP authentication handler for CURVE encryption.
    #
    # Runs a ZAP responder on +inproc://zeromq.zap.01+ in a background thread,
    # authenticating CURVE clients by their public key. No filesystem access needed.
    #
    # @example Allow specific clients
    #   auth = CZTop::CURVE::Auth.new(allowed_clients: [client1_pub, client2_pub])
    #
    # @example Allow any CURVE client
    #   auth = CZTop::CURVE::Auth.new(allow_any: true)
    #
    class Auth

      # @param allowed_clients [Array<String>, nil] list of 32-byte public keys
      # @param allow_any [Boolean] if true, accept any valid CURVE client
      # @raise [NotImplementedError] if CURVE is not available
      #
      def initialize(allowed_clients: nil, allow_any: false)
        raise NotImplementedError, 'CURVE not available in this libzmq build' unless CURVE.available?
        @mutex = Mutex.new
        @allowed = allowed_clients&.map { |k| k.b.freeze }&.then { |keys| Set.new(keys) }
        @allow_any = allow_any
        @zap = CZTop::Socket::REP.new
        @zap.linger = 0
        @zap.bind('inproc://zeromq.zap.01')
        @thread = Thread.new { run }
        ObjectSpace.define_finalizer(self, self.class._poststop(@thread))
      end

      # Adds a client public key to the allowed set.
      # @param pubkey [String] 32-byte binary public key
      # @return [void]
      #
      def allow(pubkey)
        @mutex.synchronize do
          @allowed ||= Set.new
          @allowed.add(pubkey.b.freeze)
        end
      end

      # Removes a client public key from the allowed set.
      # @param pubkey [String] 32-byte binary public key
      # @return [void]
      #
      def deny(pubkey)
        @mutex.synchronize do
          @allowed&.delete(pubkey.b)
        end
      end

      # Stops the ZAP handler thread and closes the socket.
      # @return [void]
      #
      def stop
        ObjectSpace.undefine_finalizer(self)
        @zap.close
        @thread.join(1)
      end

      # @api private
      #
      def self._poststop(thread)
        ->(_id) do
          thread.kill rescue nil
        end
      end

      private

      def run
        loop do
          msg = @zap.receive
          # ZAP request: [version, request_id, domain, address, identity, mechanism, credential]
          version    = msg[0]
          request_id = msg[1]
          credential = msg[6]  # 32-byte client public key for CURVE

          status = if @allow_any
                     '200'
                   else
                     @mutex.synchronize { @allowed&.include?(credential.b) } ? '200' : '400'
                   end

          @zap.__send__(:send, [version, request_id, status, '', '', ''])
        end
      rescue
        # Socket closed or thread interrupted → exit gracefully
      end

    end

  end
end
