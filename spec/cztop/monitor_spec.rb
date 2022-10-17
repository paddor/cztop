# frozen_string_literal: true

require_relative '../spec_helper'

describe 'CZTop::Monitor::ZMONITOR_FPTR' do
  it 'points to a dynamic library symbol' do
    assert_kind_of FFI::DynamicLibrary::Symbol, CZTop::Monitor::ZMONITOR_FPTR
  end
end

describe CZTop::Monitor do
  subject { CZTop::Monitor.new(rep_socket) }
  let(:actor) { subject.actor }
  i = 55_578
  let(:endpoint) { "tcp://127.0.0.1:#{i += 1}" }
  let(:req_socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:rep_socket) { CZTop::Socket::REP.new(endpoint) }

  after do
    subject.terminate
  end

  it 'initializes and terminates' do
    subject
  end

  describe '#initialize' do
    context 'with socket' do
      it 'passes socket' do
        expect(CZTop::Actor).to receive(:new)
          .with(CZTop::Monitor::ZMONITOR_FPTR, rep_socket).and_call_original
        subject
      end
    end
  end

  describe '#verbose' do
    it 'sends correct message to actor' do
      expect(actor).to receive(:<<).with('VERBOSE').and_call_original
      subject.verbose!
    end
  end

  describe '#listen' do
    context 'with one valid event' do
      let(:event) { 'CONNECTED' }
      after { subject.listen(event) }
      it 'tells zmonitor actor' do
        expect(actor).to receive(:<<).with(['LISTEN', event])
      end
    end
    context 'with multiple valid events' do
      let(:events) { %w[CONNECTED DISCONNECTED] }
      after { subject.listen(*events) }
      it 'tells zmonitor actor' do
        expect(actor).to receive(:<<).with(['LISTEN', *events])
      end
    end
    context 'with invalid event' do
      let(:event) { :FOO }
      it 'raises' do
        assert_raises(ArgumentError) do
          subject.listen(event)
        end
      end
    end
  end

  describe '#start' do
    after { subject.start }
    it 'tells zmonitor to start' do
      expect(actor).to receive(:<<).with('START').and_call_original
    end
    it 'waits' do
      expect(actor).to receive(:wait).and_call_original
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
    it 'returns Message' do
      subject.listen(*%w[ACCEPTED CLOSED MONITOR_STOPPED])
      subject.actor.options.rcvtimeo = 100
      subject.start
      req_socket # connects
      assert_kind_of CZTop::Message, subject.next
    end
    it 'gets the next event' do
      subject.listen(*%w[ACCEPTED CLOSED MONITOR_STOPPED])
      subject.start
      req_socket # connects
      req_socket.disconnect(endpoint)
      subject.actor.options.rcvtimeo = 100
      assert_equal 'ACCEPTED', subject.next[0]
      rep_socket.ffi_delegate.destroy
      assert_equal 'CLOSED', subject.next[0]
      assert_equal 'MONITOR_STOPPED', subject.next[0]
    end
  end
end
