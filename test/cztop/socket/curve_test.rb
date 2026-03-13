# frozen_string_literal: true

require_relative '../test_helper'


describe 'CURVE socket integration' do
  before { skip unless CZTop::CURVE.available? }

  let(:server_pub) { @server_pub }
  let(:server_sec) { @server_sec }
  let(:client_pub) { @client_pub }
  let(:client_sec) { @client_sec }

  before do
    @server_pub, @server_sec = CZTop::CURVE.keypair
    @client_pub, @client_sec = CZTop::CURVE.keypair
  end


  describe 'REQ/REP round-trip with allowed client' do
    it 'sends and receives encrypted messages' do
      auth = CZTop::CURVE::Auth.new(allowed_clients: [client_pub])

      server = CZTop::Socket::REP.new('tcp://127.0.0.1:*',
                 curve: { secret_key: server_sec })
      port = server.last_tcp_port

      client = CZTop::Socket::REQ.new("tcp://127.0.0.1:#{port}",
                 curve: { secret_key: client_sec, server_key: server_pub })

      client.options.sndtimeo = 2000
      client.options.rcvtimeo = 2000
      server.options.rcvtimeo = 2000
      server.options.sndtimeo = 2000

      client << 'hello'
      msg = server.receive
      assert_equal 'hello', msg[0]

      server << 'world'
      msg = client.receive
      assert_equal 'world', msg[0]

      auth.stop
      server.close
      client.close
    end
  end


  describe 'allow_any: true round-trip' do
    it 'accepts any valid CURVE client' do
      auth = CZTop::CURVE::Auth.new(allow_any: true)

      server = CZTop::Socket::REP.new('tcp://127.0.0.1:*',
                 curve: { secret_key: server_sec })
      port = server.last_tcp_port

      client = CZTop::Socket::REQ.new("tcp://127.0.0.1:#{port}",
                 curve: { secret_key: client_sec, server_key: server_pub })

      client.options.sndtimeo = 2000
      client.options.rcvtimeo = 2000
      server.options.rcvtimeo = 2000
      server.options.sndtimeo = 2000

      client << 'ping'
      msg = server.receive
      assert_equal 'ping', msg[0]

      auth.stop
      server.close
      client.close
    end
  end


  describe 'rejected client' do
    it 'times out when client key is not allowed' do
      _, other_sec = CZTop::CURVE.keypair
      auth = CZTop::CURVE::Auth.new(allowed_clients: [client_pub])

      server = CZTop::Socket::REP.new('tcp://127.0.0.1:*',
                 curve: { secret_key: server_sec })
      port = server.last_tcp_port

      # Use a key NOT in the allowed list
      rejected = CZTop::Socket::REQ.new("tcp://127.0.0.1:#{port}",
                   curve: { secret_key: other_sec, server_key: server_pub })

      rejected.options.sndtimeo = 500
      server.options.rcvtimeo = 500

      rejected << 'hello' rescue nil  # may or may not raise

      assert_raises(Errno::EAGAIN, IO::TimeoutError) { server.receive }

      auth.stop
      server.close
      rejected.close
    end
  end


  describe 'invalid curve: kwarg' do
    it 'raises ArgumentError for wrong secret_key size' do
      assert_raises(ArgumentError) do
        CZTop::Socket::REQ.new('tcp://127.0.0.1:5555',
          curve: { secret_key: 'too_short', server_key: "\x00" * 32 })
      end
    end

    it 'raises ArgumentError for wrong server_key size' do
      _, sec = CZTop::CURVE.keypair
      assert_raises(ArgumentError) do
        CZTop::Socket::REQ.new('tcp://127.0.0.1:5555',
          curve: { secret_key: sec, server_key: 'too_short' })
      end
    end
  end

end
