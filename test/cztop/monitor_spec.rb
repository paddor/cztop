# frozen_string_literal: true

require_relative '../spec_helper'

describe 'CZTop::Monitor::ZMONITOR_FPTR' do
  it 'points to a dynamic library symbol' do
    assert_kind_of FFI::DynamicLibrary::Symbol, CZTop::Monitor::ZMONITOR_FPTR
  end
end


describe CZTop::Monitor do
  let(:subject) { CZTop::Monitor.new(rep_socket) }
  let(:actor) { subject.actor }
  let(:rep_socket) do
    s = CZTop::Socket::REP.new
    s.bind("tcp://127.0.0.1:*")
    s
  end
  let(:endpoint) { rep_socket.last_endpoint }
  let(:req_socket) { CZTop::Socket::REQ.new(endpoint) }

  after do
    subject.terminate
  end

  it 'initializes and terminates' do
    subject
  end


  describe '#initialize' do
    describe 'with socket' do
      it 'creates actor with ZMONITOR_FPTR and socket' do
        created_with = nil
        original_new = CZTop::Actor.method(:new)
        CZTop::Actor.stub(:new, ->(*args) { created_with = args; original_new.call(*args) }) do
          subject
        end
        assert_equal CZTop::Monitor::ZMONITOR_FPTR, created_with[0]
        assert_same rep_socket, created_with[1]
      end
    end
  end


  describe '#verbose' do
    it 'sends correct message to actor' do
      sent = nil
      original_send = actor.method(:<<)
      actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
        subject.verbose!
      end
      assert_equal 'VERBOSE', sent
    end
  end


  describe '#listen' do
    describe 'with one valid event' do
      let(:event) { 'CONNECTED' }

      it 'tells zmonitor actor' do
        sent = nil
        actor.stub(:<<, ->(*args) { sent = args[0] }) do
          subject.listen(event)
        end
        assert_equal ['LISTEN', event], sent
      end
    end


    describe 'with multiple valid events' do
      let(:events) { %w[CONNECTED DISCONNECTED] }

      it 'tells zmonitor actor' do
        sent = nil
        actor.stub(:<<, ->(*args) { sent = args[0] }) do
          subject.listen(*events)
        end
        assert_equal ['LISTEN', *events], sent
      end
    end


    describe 'with invalid event' do
      let(:event) { :FOO }

      it 'raises' do
        assert_raises(ArgumentError) do
          subject.listen(event)
        end
      end
    end
  end


  describe '#start' do
    it 'tells zmonitor to start' do
      sent = nil
      original_send = actor.method(:<<)
      actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
        subject.start
      end
      assert_equal 'START', sent
    end
  end


  describe '#fd' do
    it 'returns FD' do
      assert_equal subject.actor.options.fd, subject.fd
    end
  end


  describe '#readable?' do
    it 'returns false if no event is available' do
      subject.listen(*%w[ACCEPTED CLOSED MONITOR_STOPPED])
      subject.start
      refute_operator subject, :readable?
    end

    it 'returns true if an event is available' do
      subject.listen(*%w[ACCEPTED CLOSED MONITOR_STOPPED])
      subject.start
      req_socket
      sleep 0.1
      assert_operator subject, :readable?
    end
  end


  describe '#next' do
    it 'returns Array' do
      subject.listen(*%w[ACCEPTED CLOSED MONITOR_STOPPED])
      subject.actor.options.rcvtimeo = 500
      subject.start
      req_socket # connects
      assert_kind_of Array, subject.next
    end

    it 'gets the next event' do
      subject.listen(*%w[ACCEPTED CLOSED MONITOR_STOPPED])
      subject.start
      req_socket # connects
      req_socket.disconnect(endpoint)
      subject.actor.options.rcvtimeo = 500
      assert_equal 'ACCEPTED', subject.next[0]
      rep_socket.ffi_delegate.destroy
      assert_equal 'CLOSED', subject.next[0]
      assert_equal 'MONITOR_STOPPED', subject.next[0]
    end
  end
end
