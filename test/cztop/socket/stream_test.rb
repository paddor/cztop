# frozen_string_literal: true

require_relative '../test_helper'
require 'socket'

describe CZTop::Socket::STREAM do
  describe 'integration with raw TCP' do
    describe 'STREAM server with TCPSocket client' do
      it 'accepts a raw TCP connection and exchanges data' do
        stream = CZTop::Socket::STREAM.new
        stream.send_timeout = 0.5
        stream.recv_timeout = 0.5

        port = stream.bind('tcp://127.0.0.1:*')

        tcp = TCPSocket.new('127.0.0.1', port)

        # First message from new connection: [identity, ''] (connect notification)
        msg = stream.receive
        assert_equal 2, msg.size
        identity = msg[0]
        refute_empty identity
        assert_equal '', msg[1]

        # TCP client sends data
        tcp.write("hello from tcp\n")
        tcp.flush

        msg = stream.receive
        assert_equal 2, msg.size
        assert_equal identity, msg[0]
        assert_includes msg[1], 'hello from tcp'

        # STREAM sends back: [identity, response_data]
        stream << [identity, "reply from stream\n"]

        response = tcp.gets
        assert_includes response, 'reply from stream'

        # Close TCP connection
        tcp.close

        # Disconnect notification: [identity, '']
        msg = stream.receive
        assert_equal 2, msg.size
        assert_equal identity, msg[0]
        assert_equal '', msg[1]
      end


      it 'handles multiple TCP clients' do
        stream = CZTop::Socket::STREAM.new
        stream.send_timeout = 0.5
        stream.recv_timeout = 0.5

        port = stream.bind('tcp://127.0.0.1:*')

        clients = 3.times.map { TCPSocket.new('127.0.0.1', port) }
        identities = {}

        # Collect connect notifications
        clients.each do |tcp|
          msg = stream.receive
          assert_equal 2, msg.size
          assert_equal '', msg[1]
          identities[tcp] = msg[0]
        end

        # Each client sends, STREAM receives with correct identity
        clients.each_with_index do |tcp, n|
          tcp.write("client_#{n}\n")
          tcp.flush
        end

        received = {}
        clients.size.times do
          msg = stream.receive
          received[msg[0]] = msg[1]
        end

        clients.each_with_index do |tcp, n|
          id = identities[tcp]
          assert_includes received[id], "client_#{n}"
        end

        clients.each(&:close)
      end
    end


    describe 'STREAM client connecting to a TCP server' do
      it 'connects to a raw TCP server and exchanges data' do
        tcp_server = TCPServer.new('127.0.0.1', 0)
        port = tcp_server.addr[1]

        stream = CZTop::Socket::STREAM.new
        stream.send_timeout = 0.5
        stream.recv_timeout = 0.5
        stream.connect("tcp://127.0.0.1:#{port}")

        client_sock = tcp_server.accept

        # STREAM receives connect notification for its own connection
        msg = stream.receive
        assert_equal 2, msg.size
        identity = msg[0]
        refute_empty identity
        assert_equal '', msg[1]

        # Send data from STREAM to TCP server
        stream << [identity, "hello from zmq\n"]

        data = client_sock.gets
        assert_includes data, 'hello from zmq'

        # TCP server sends data back
        client_sock.write("reply from server\n")
        client_sock.flush

        msg = stream.receive
        assert_equal 2, msg.size
        assert_equal identity, msg[0]
        assert_includes msg[1], 'reply from server'

        client_sock.close
        tcp_server.close
      end
    end


    describe 'echo server pattern' do
      it 'echoes data back to TCP client' do
        stream = CZTop::Socket::STREAM.new
        stream.send_timeout = 0.5
        stream.recv_timeout = 0.5

        port = stream.bind('tcp://127.0.0.1:*')

        tcp = TCPSocket.new('127.0.0.1', port)

        # Consume connect notification
        msg = stream.receive
        identity = msg[0]

        # Client sends data
        tcp.write("echo this\n")
        tcp.flush

        msg = stream.receive
        assert_equal identity, msg[0]
        data = msg[1]

        # Echo it back
        stream << [identity, data]

        response = tcp.gets
        assert_includes response, 'echo this'

        tcp.close
      end
    end
  end
end
