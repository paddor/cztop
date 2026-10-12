# frozen_string_literal: true

require_relative 'test_helper'


class CZTopMonitorTest < Minitest::Spec
  it 'rejects receive after close' do
    server = CZTop::Socket::REP.new
    @monitor = CZTop::Monitor.new(server)
    @monitor.close
    assert_nil @monitor.close
    assert_raises(IOError) { @monitor.receive }
  ensure
    server&.close
  end

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


class CZTopMonitorCleanupTest < Minitest::Spec
  before do
    @server = CZTop::Socket::REP.new
  end

  after do
    @monitor&.close
    @server.close
  end

  def monitor
    @monitor ||= CZTop::Monitor.new(@server)
  end

  it 'removes the finalizer before native destruction' do
    subject = monitor
    events = []
    unregister = ObjectSpace.method(:undefine_finalizer)
    destroy = CZMQ::FFI.method(:zactor_destroy)
    ObjectSpace.stub(:undefine_finalizer, ->(object) {
      events << :unregister
      unregister.call(object)
    }) do
      CZMQ::FFI.stub(:zactor_destroy, ->(ref) {
        events << :destroy
        destroy.call(ref)
      }) { subject.close }
    end
    assert_equal [:unregister, :destroy], events
  end

  it 'leaves a pending finalizer with a null pointer after native destruction' do
    finalizer = nil
    register = ObjectSpace.method(:define_finalizer)
    ObjectSpace.stub(:define_finalizer, ->(object, callback) {
      finalizer = callback
      register.call(object, callback)
    }) { monitor }

    pointers = []
    destroy = CZMQ::FFI.method(:zactor_destroy)
    CZMQ::FFI.stub(:zactor_destroy, ->(ref) {
      pointers << ref.read_pointer
      # Avoid a native double free if the finalizer still holds a stale pointer.
      destroy.call(ref) if pointers.length == 1 || ref.read_pointer.null?
    }) do
      monitor.close
      finalizer.call(monitor.object_id)
    end
    assert_equal 2, pointers.length
    refute pointers.first.null?
    assert pointers.last.null?, 'finalizer retains a destroyed monitor'
  end

  it 'marks itself closed and rejects repeated close during native destruction' do
    subject = monitor
    calls = 0
    closed = false
    destroy = CZMQ::FFI.method(:zactor_destroy)
    CZMQ::FFI.stub(:zactor_destroy, ->(ref) {
      calls += 1
      if calls == 1
        closed = subject.closed?
        subject.close
        destroy.call(ref)
      end
    }) { subject.close }
    assert_equal 1, calls
    assert closed
    assert_nil subject.close
  end
end
