# frozen_string_literal: true

require_relative 'test_helper'


describe CZTop::Monitor do
  after do
    @monitor&.close
  end


  it 'detects LISTENING event on bind' do
    server = CZTop::Socket::REP.new
    server.recv_timeout = 0.1
    @monitor = CZTop::Monitor.new(server, 'LISTENING')

    server.bind('tcp://127.0.0.1:*')

    event = @monitor.receive(timeout: 1)
    refute_nil event, 'should receive LISTENING event'
    assert_equal 'LISTENING', event.name
  end


  it 'detects ACCEPTED on incoming connection (includes peer address)' do
    server = CZTop::Socket::REP.new
    server.recv_timeout = 0.1
    @monitor = CZTop::Monitor.new(server, 'ACCEPTED')

    server.bind('tcp://127.0.0.1:*')
    endpoint = server.last_endpoint

    client = CZTop::Socket::REQ.new
    client.send_timeout = 0.1
    client.linger = 0
    client.connect(endpoint)

    event = @monitor.receive(timeout: 1)
    refute_nil event, 'should receive ACCEPTED event'
    assert_equal 'ACCEPTED', event.name
    refute_nil event.peer_address
  end


  it 'detects DISCONNECTED when peer closes' do
    server = CZTop::Socket::REP.new
    server.recv_timeout = 0.1
    @monitor = CZTop::Monitor.new(server, 'ACCEPTED', 'DISCONNECTED')

    server.bind('tcp://127.0.0.1:*')
    endpoint = server.last_endpoint

    client = CZTop::Socket::REQ.new
    client.send_timeout = 0.1
    client.linger = 0
    client.connect(endpoint)

    # Consume ACCEPTED event
    event = @monitor.receive(timeout: 1)
    assert_equal 'ACCEPTED', event.name

    client.close
    sleep 0.1

    event = @monitor.receive(timeout: 1)
    refute_nil event, 'should receive DISCONNECTED event'
    assert_equal 'DISCONNECTED', event.name
  end
end
