# frozen_string_literal: true

require_relative 'spec_helper'
require 'benchmark'

describe CZTop::Poller do
  include ZMQHelper
  before { skip 'requires ZMQ drafts' unless has_zmq_drafts? }

  let(:poller) { CZTop::Poller.new }
  let(:poller_ptr) { poller.instance_variable_get(:@poller_ptr) }

  i = 0
  let(:endpoint1) { "inproc://poller_spec_rw1_#{i += 1}" }
  let(:endpoint2) { "inproc://poller_spec_rw2_#{i += 1}" }
  let(:endpoint3) { "inproc://poller_spec_rw3_#{i += 1}" }

  let(:reader1) { CZTop::Socket::PULL.new(endpoint1) }
  let(:reader2) { CZTop::Socket::PULL.new(endpoint2) }
  let(:reader3) { CZTop::Socket::PULL.new(endpoint3) }

  let(:writer1) { CZTop::Socket::PUSH.new(endpoint1) }
  let(:writer2) { CZTop::Socket::PUSH.new(endpoint2) }
  let(:writer3) { CZTop::Socket::PUSH.new(endpoint3) }

  let(:socket_ptr) { CZMQ::FFI::Zsock.resolve(socket) }
  let(:event) { poller.wait(20) }

  POLLIN = CZTop::Poller::ZMQ::POLLIN
  POLLOUT = CZTop::Poller::ZMQ::POLLOUT

  describe '#initialize' do
    describe 'with no readers' do
      it 'initializes empty' do
        assert_equal [], poller.sockets
      end
    end
    describe 'with one reader' do
      let(:socket) { reader1 }
      it 'adds reader' do
        p = CZTop::Poller.new(socket)
        assert_includes p.sockets, socket
      end
    end
    describe 'with multiple readers' do
      let(:poller) { CZTop::Poller.new(reader1, reader2) }
      it 'adds readers' do
        assert_equal 2, poller.sockets.size
        assert_operator poller.sockets, :include?, reader1
        assert_operator poller.sockets, :include?, reader2
        poller.sockets.each do |socket|
          assert_equal POLLIN, poller.event_mask_for_socket(socket)
        end
      end
    end
  end

  describe '#add' do
    describe 'with reader' do
      let(:socket) { reader1 }
      it 'adds reader socket' do
        called_with = nil
        original = CZTop::Poller::ZMQ.method(:poller_add)
        CZTop::Poller::ZMQ.stub(:poller_add, ->(*args) { called_with = args; original.call(*args) }) do
          poller.add(socket, POLLIN)
        end
        assert_equal [poller_ptr, socket_ptr, nil, POLLIN], called_with
        assert_includes poller.sockets, reader1
      end
    end
    describe 'with writer' do
      let(:socket) { writer1 }
      it 'adds writer socket' do
        called_with = nil
        original = CZTop::Poller::ZMQ.method(:poller_add)
        CZTop::Poller::ZMQ.stub(:poller_add, ->(*args) { called_with = args; original.call(*args) }) do
          poller.add(socket, POLLOUT)
        end
        assert_equal [poller_ptr, socket_ptr, nil, POLLOUT], called_with
        assert_includes poller.sockets, writer1
      end
    end
    describe 'with non-socket' do
      it 'raises' do
        assert_raises(ArgumentError) { poller.add('foo', POLLOUT) }
      end
    end
  end

  describe '#add_reader' do
    it 'adds reader' do
      called_with = nil
      original = poller.method(:add)
      poller.stub(:add, ->(*args) { called_with = args; original.call(*args) }) do
        poller.add_reader(reader1)
      end
      assert_equal [reader1, POLLIN], called_with
    end
  end

  describe '#add_writer' do
    it 'adds writer' do
      called_with = nil
      original = poller.method(:add)
      poller.stub(:add, ->(*args) { called_with = args; original.call(*args) }) do
        poller.add_writer(writer1)
      end
      assert_equal [writer1, POLLOUT], called_with
    end
  end

  describe '#modify' do
    describe 'with registered socket' do
      let(:socket) { reader1 }
      let(:events) { POLLIN | POLLOUT }
      before { poller.add_reader(reader1) }
      it 'modifies events' do
        called_with = nil
        original = CZTop::Poller::ZMQ.method(:poller_modify)
        CZTop::Poller::ZMQ.stub(:poller_modify, ->(*args) { called_with = args; original.call(*args) }) do
          poller.modify(reader1, events)
        end
        assert_equal [poller_ptr, socket_ptr, events], called_with
      end
    end
    describe 'with unregistered socket' do
      it 'raises' do
        assert_raises(ArgumentError) { poller.modify(reader1, POLLIN) }
      end
    end
  end

  describe '#remove' do
    describe 'with registered socket' do
      let(:socket) { reader1 }
      before { poller.add_reader(socket) }
      it 'removes reader' do
        called_with = nil
        original = CZTop::Poller::ZMQ.method(:poller_remove)
        CZTop::Poller::ZMQ.stub(:poller_remove, ->(*args) { called_with = args; original.call(*args) }) do
          poller.remove(socket)
        end
        assert_equal [poller_ptr, socket_ptr], called_with
        refute_includes poller.sockets, reader1
      end
    end
    describe 'with unregistered reader' do
      it 'raises' do
        assert_raises(ArgumentError) { poller.remove(reader1) }
      end
    end
    describe 'with non-socket' do
      it 'raises' do
        assert_raises(ArgumentError) { poller.remove('foo') }
      end
    end
  end

  describe '#remove_reader' do
    describe 'with socket registered for readability only' do
      let(:socket) { reader1 }
      before { poller.add_reader(socket) }
      it 'removes reader' do
        called_with = nil
        original = poller.method(:remove)
        poller.stub(:remove, ->(*args) { called_with = args; original.call(*args) }) do
          poller.remove_reader(socket)
        end
        assert_equal [socket], called_with
      end
    end
    describe 'with unregistered reader' do
      it 'raises' do
        assert_raises(ArgumentError) { poller.remove_reader(reader1) }
      end
    end
    describe 'with socket registered for writability' do
      let(:socket) { writer1 }
      before { poller.add_writer(socket) }
      it 'raises' do
        assert_raises(ArgumentError) { poller.remove_reader(socket) }
      end
    end
    describe 'with socket registered for readability and writability' do
      let(:socket) { CZTop::Socket::DEALER.new(endpoint1) }
      before { poller.add(socket, POLLIN | POLLOUT) }
      it 'raises' do
        assert_raises(ArgumentError) { poller.remove_reader(socket) }
      end
    end
  end

  describe '#remove_writer' do
    describe 'with socket registered for writability only' do
      let(:socket) { writer1 }
      before { poller.add_writer(socket) }
      it 'removes writer' do
        called_with = nil
        original = poller.method(:remove)
        poller.stub(:remove, ->(*args) { called_with = args; original.call(*args) }) do
          poller.remove_writer(socket)
        end
        assert_equal [socket], called_with
      end
    end
    describe 'with unregistered writer' do
      it 'raises' do
        assert_raises(ArgumentError) { poller.remove_writer(writer1) }
      end
    end
    describe 'with socket registered for readability' do
      let(:socket) { reader1 }
      before { poller.add_reader(socket) }
      it 'raises' do
        assert_raises(ArgumentError) { poller.remove_writer(socket) }
      end
    end
    describe 'with socket registered for readability and writability' do
      let(:socket) { CZTop::Socket::DEALER.new(endpoint1) }
      before { poller.add(socket, POLLIN | POLLOUT) }
      it 'raises' do
        assert_raises(ArgumentError) { poller.remove_writer(socket) }
      end
    end
  end

  describe '#wait' do
    describe 'in general' do
      let(:poller_ptr) { poller.instance_variable_get(:@poller_ptr) }
      let(:event_ptr) { poller.instance_variable_get(:@event_ptr) }

      before do
        poller.add(reader1, POLLIN)
        poller.add(reader2, POLLIN)
        poller.add(reader3, POLLIN)
        poller.add(writer1, POLLOUT)
        poller.add(writer2, POLLOUT)
        poller.add(writer3, POLLOUT)
      end

      it 'passes arguments to zmq_poller_wait()' do
        called_with = nil
        CZTop::Poller::ZMQ.stub(:poller_wait, ->(*args) { called_with = args; -1 }) do
          CZMQ::FFI::Errors.stub(:errno, Errno::ETIMEDOUT::Errno) do
            poller.wait(15)
          end
        end
        assert_equal [poller_ptr, event_ptr, 15], called_with
      end
    end

    describe 'with no registered sockets' do
      it "doesn't raise" do
        poller.wait(0)
      end
    end

    describe 'with readable socket' do
      before do
        writer1 << 'foobar'
        poller.add(reader1, POLLIN)
      end
      it 'returns first readable socket' do
        assert_same reader1, event.socket
        assert_operator event, :readable?
      end
    end
    describe 'with no readable socket' do
      before do
        poller.add(reader1, POLLIN)
      end
      it 'returns nil' do
        assert_nil poller.wait(20)
      end
    end

    describe 'with thread-safe sockets' do
      before { skip 'requires CZMQ drafts' unless has_czmq_drafts? }

      i = 0
      let(:endpoint) { "inproc://poller_spec_srv_client_#{i += 1}" }
      let(:server) { CZTop::Socket::SERVER.new(endpoint) }
      let(:client) { CZTop::Socket::CLIENT.new(endpoint) }
      let(:poller) { CZTop::Poller.new(server) }

      describe 'with message from client' do
        before do
          client << 'foobar'
        end
        it 'makes server socket readable' do
          assert_same server, event.socket
          assert_operator event, :readable?
        end
      end
    end
  end

  describe '#simple_wait' do
    describe 'with event' do
      before do
        writer1 << 'foobar'
        poller.add_reader(reader1)
      end
      it 'returns socket' do
        assert_same reader1, poller.simple_wait(20)
      end
    end
    describe 'with timeout expired' do
      before do
        poller.add_reader(reader1)
      end
      it 'returns nil' do
        assert_nil poller.simple_wait(20)
      end
    end
  end

  describe 'with actor' do
    let(:actor) do # echo actor
      CZTop::Actor.new { |msg, pipe| pipe << msg }
    end

    before do
      poller.add_reader(actor)
    end
    after do
      actor.terminate
    end

    describe 'with unreadable actor' do
      it 'returns nil' do
        assert_nil poller.wait(20)
      end
    end
    describe 'with readable actor' do
      before { actor << 'foo' }
      it 'returns actor' do
        assert_same actor, event.socket
      end
    end
  end

  describe '#socket_for_ptr' do
    let(:socket) { reader1 }
    describe 'with known pointer' do
      before { poller.add_reader(socket) }
      it 'returns socket' do
        assert_same socket, poller.socket_for_ptr(socket_ptr)
      end
    end
    describe 'with unknown pointer' do
      it 'raises' do
        assert_raises(ArgumentError) do
          poller.socket_for_ptr(socket_ptr)
        end
      end
    end
  end

  describe '#sockets' do
    describe 'with no registered sockets' do
      it 'returns empty array' do
        assert_equal [], poller.sockets
      end
    end
    describe 'with registered sockets' do
      before do
        poller.add_reader(reader1)
        poller.add_writer(writer2)
      end
      it 'returns registered sockets' do
        assert_equal [reader1, writer2], poller.sockets
      end
    end
  end

  describe '#event_mask_for_socket' do
    describe 'for registered reader socket' do
      before { poller.add_reader(reader1) }
      it 'returns event mask' do
        assert_equal POLLIN, poller.event_mask_for_socket(reader1)
      end
    end
    describe 'for registered writer socket' do
      before { poller.add_writer(writer1) }
      it 'returns event mask' do
        assert_equal POLLOUT, poller.event_mask_for_socket(writer1)
      end
    end
    describe 'for registered reader/writer socket (in 1 step)' do
      let(:socket) { CZTop::Socket::DEALER.new(endpoint1) }
      before do
        poller.add(socket, POLLIN | POLLOUT)
      end
      it 'returns event mask' do
        assert_equal POLLIN | POLLOUT, poller.event_mask_for_socket(socket)
      end
    end

    describe 'for unregistered socket' do
      it 'raises' do
        assert_raises(ArgumentError) do
          poller.event_mask_for_socket(reader1)
        end
      end
    end
  end

  describe CZTop::Poller::Aggregated do
    let(:poller) { CZTop::Poller.new }
    let(:aggpoller) { CZTop::Poller::Aggregated.new(poller) }

    describe '#poller' do
      it 'returns associated CZTop::Poller' do
        assert_same poller, aggpoller.poller
      end
    end

    describe '#wait' do
      describe 'when building lists' do
        let(:readables_before) { aggpoller.readables }
        let(:writables_before) { aggpoller.writables }
        before do
          readables_before
          writables_before
          aggpoller.wait(0)
        end
        it 'builds completely new lists' do # forgetting the previous ones
          refute_same readables_before, aggpoller.readables
          refute_same writables_before, aggpoller.writables
        end
      end

      describe 'when calling CZTop::Poller#wait' do
        it 'passes timeout' do
          called_with = nil
          original = poller.method(:wait)
          poller.stub(:wait, ->(*args) { called_with = args; original.call(*args) }) do
            aggpoller.wait(11)
          end
          assert_equal [11], called_with
        end
      end

      describe 'with new event' do
        before do
          writer1 << 'foobar'
          poller.add_reader(reader1)
        end
        it 'returns true' do
          assert aggpoller.wait(20)
        end
      end
      describe 'with no event' do
        it 'returns false' do
          refute aggpoller.wait(0)
        end
      end

      describe 'having been called previously' do
        before do
          writer1 << "i'll teach you how to read"
          poller.add_reader(reader1)
          poller.add_writer(writer1)
          aggpoller.wait(20)
          assert_includes aggpoller.readables, reader1
        end
        it 'is level-triggered' do # recognizes the socket as readable again
          aggpoller.wait(0)
          assert_includes aggpoller.readables, reader1
        end
      end
    end

    describe '#readables' do
      it 'returns array' do
        assert_kind_of Array, aggpoller.readables
      end
      describe 'with no previous call to #wait' do
        it 'returns empty array' do
          assert_equal [], aggpoller.readables
        end
      end
      describe 'with readable and unreadable socket' do
        before do
          writer1 << 'foobar'
          poller.add_reader(reader1) # readable
          poller.add_reader(reader2) # unreadable
          poller.add_writer(writer1) # a writer
          aggpoller.wait(20)
        end
        it 'returns readable socket' do
          assert_equal [reader1], aggpoller.readables
        end
      end
    end

    describe '#writables' do
      it 'returns array' do
        assert_kind_of Array, aggpoller.writables
      end
      describe 'with no previous call to #wait' do
        it 'returns empty array' do
          assert_equal [], aggpoller.writables
        end
      end
      describe 'with writable and unwritable sockets' do
        let(:writable) { CZTop::Socket::DEALER.new(endpoint1) }
        let(:unwritable) do
          s = CZTop::Socket::DEALER.new # an unconnected socket is not writable
          s.options.sndtimeo = 10 # don't block forever
          s
        end
        before do
          poller.add_writer(writable) # writable
          poller.add_writer(unwritable) # unwritable
          poller.add_reader(reader3) # a reader
          aggpoller.wait(20)
        end
        it 'returns writable socket' do
          assert_equal [writable], aggpoller.writables
        end
      end
    end

    describe 'forwarded methods' do
      let(:obj) { Object.new }
      describe '#add' do
        it 'forwards to Poller' do
          called_with = nil
          poller.stub(:add, ->(*args) { called_with = args; :foo }) do
            assert_equal :foo, aggpoller.add(obj)
          end
          assert_equal [obj], called_with
        end
      end
      describe '#add_reader' do
        it 'forwards to Poller' do
          called_with = nil
          poller.stub(:add_reader, ->(*args) { called_with = args; :foo }) do
            assert_equal :foo, aggpoller.add_reader(obj)
          end
          assert_equal [obj], called_with
        end
      end
      describe '#add_writer' do
        it 'forwards to Poller' do
          called_with = nil
          poller.stub(:add_writer, ->(*args) { called_with = args; :foo }) do
            assert_equal :foo, aggpoller.add_writer(obj)
          end
          assert_equal [obj], called_with
        end
      end
      describe '#modify' do
        it 'forwards to Poller' do
          called_with = nil
          poller.stub(:modify, ->(*args) { called_with = args; :foo }) do
            assert_equal :foo, aggpoller.modify(obj)
          end
          assert_equal [obj], called_with
        end
      end
      describe '#remove' do
        it 'forwards to Poller' do
          called_with = nil
          poller.stub(:remove, ->(*args) { called_with = args; :foo }) do
            assert_equal :foo, aggpoller.remove(obj)
          end
          assert_equal [obj], called_with
        end
      end
      describe '#remove_reader' do
        it 'forwards to Poller' do
          called_with = nil
          poller.stub(:remove_reader, ->(*args) { called_with = args; :foo }) do
            assert_equal :foo, aggpoller.remove_reader(obj)
          end
          assert_equal [obj], called_with
        end
      end
      describe '#remove_writer' do
        it 'forwards to Poller' do
          called_with = nil
          poller.stub(:remove_writer, ->(*args) { called_with = args; :foo }) do
            assert_equal :foo, aggpoller.remove_writer(obj)
          end
          assert_equal [obj], called_with
        end
      end
      describe '#sockets' do
        it 'forwards to Poller' do
          called_with = nil
          poller.stub(:sockets, ->(*args) { called_with = args; :foo }) do
            assert_equal :foo, aggpoller.sockets(obj)
          end
          assert_equal [obj], called_with
        end
      end
    end
  end
end

describe CZTop::Poller::ZPoller do
  include HasFFIDelegateExamples
  include ZMQHelper
  before { skip 'requires ZMQ drafts' unless has_zmq_drafts? }

  let(:poller) { CZTop::Poller::ZPoller.new(reader1) }
  let(:ffi_delegate) { poller.ffi_delegate }
  i = 0
  let(:reader1) { CZTop::Socket::PULL.new("inproc://zpoller_spec_r1_#{i += 1}") }
  let(:reader2) { CZTop::Socket::PULL.new("inproc://zpoller_spec_r2_#{i += 1}") }
  let(:reader3) { CZTop::Socket::PULL.new("inproc://zpoller_spec_r3_#{i += 1}") }

  describe '#initialize' do
    describe 'with one reader' do
      it 'passes reader' do
        called_with = nil
        original = CZMQ::FFI::Zpoller.method(:new)
        CZMQ::FFI::Zpoller.stub(:new, ->(*args) { called_with = args; original.call(*args) }) do
          CZTop::Poller::ZPoller.new(reader1)
        end
        assert_equal [reader1, :pointer, nil], called_with
      end

      it 'remembers the reader' do
        p = CZTop::Poller::ZPoller.new(reader1)
        sockets = p.instance_variable_get(:@sockets)
        assert_includes sockets.keys, CZMQ::FFI::Zsock.resolve(reader1)
      end
    end

    describe 'with additional readers' do
      it 'passes all readers' do
        called_with = nil
        original = CZMQ::FFI::Zpoller.method(:new)
        CZMQ::FFI::Zpoller.stub(:new, ->(*args) { called_with = args; original.call(*args) }) do
          CZTop::Poller::ZPoller.new(reader1, reader2, reader3)
        end
        assert_equal [reader1, :pointer, reader2, :pointer, reader3, :pointer, nil], called_with
      end

      it 'remembers all readers' do
        p = CZTop::Poller::ZPoller.new(reader1, reader2, reader3)
        sockets = p.instance_variable_get(:@sockets)
        [reader1, reader2, reader3].each do |r|
          assert_includes sockets.keys, CZMQ::FFI::Zsock.resolve(r)
        end
      end
    end
  end

  describe '#add' do
    it 'adds reader' do
      called_with = nil
      original = ffi_delegate.method(:add)
      ffi_delegate.stub(:add, ->(*args) { called_with = args; original.call(*args) }) do
        poller.add(reader2)
      end
      assert_equal [reader2], called_with
    end

    it 'remembers the reader' do
      poller.add(reader2)
      sockets = poller.instance_variable_get(:@sockets)
      assert_includes sockets.keys, CZMQ::FFI::Zsock.resolve(reader2)
    end

    describe 'with failure' do
      it 'raises' do
        ffi_delegate.stub(:add, ->(*) { -1 }) do
          CZMQ::FFI::Errors.stub(:errno, Errno::EPERM::Errno) do
            assert_raises(SystemCallError) { poller.add(reader2) }
          end
        end
      end
    end
  end

  describe '#remove' do
    it 'removes reader' do
      called_with = nil
      original = ffi_delegate.method(:remove)
      ffi_delegate.stub(:remove, ->(*args) { called_with = args; original.call(*args) }) do
        poller.remove(reader1)
      end
      assert_equal [reader1], called_with
    end

    it 'forgets the reader' do
      poller.remove(reader1)
      sockets = poller.instance_variable_get(:@sockets)
      refute_includes sockets.keys, CZMQ::FFI::Zsock.resolve(reader1)
    end

    describe 'with failure' do
      it 'raises' do
        ffi_delegate.stub(:remove, ->(*) { -1 }) do
          CZMQ::FFI::Errors.stub(:errno, Errno::EPERM::Errno) do
            assert_raises(SystemCallError) { poller.remove(reader2) }
          end
        end
      end
    end

    describe 'with unregistered socket' do
      it 'fails' do
        assert_raises(ArgumentError) { poller.remove(reader2) }
      end
    end
  end

  describe '#wait' do
    describe 'with readable socket' do
      before do
        CZTop::Socket::PUSH.new(reader1.last_endpoint) << 'foo'
      end
      it 'returns socket' do
        assert_same reader1, poller.wait
      end
    end
    describe 'with expired timeout' do
      it 'returns nil' do
        assert_nil poller.wait(0)
      end
    end
    describe 'with interrupt' do
      it 'raises Interrupt' do
        ffi_delegate.stub(:terminated, true) do
          assert_raises(Interrupt) do
            poller.wait(0)
          end
        end
      end
    end

    it 'the timeout is in ms' do
      duration = Benchmark.realtime { poller.wait(30) }
      assert_in_delta 0.03, duration, 0.02 # +- 20ms is OK
    end

    describe 'with no timeout' do
      it 'waits indefinitely' do
        called_with = nil
        ffi_delegate.stub(:wait, ->(*args) { called_with = args; FFI::Pointer::NULL }) do
          poller.wait
        end
        assert_equal [-1], called_with
      end
    end

    describe 'with wrong pointer from zpoller_wait' do
      it 'raises' do
        wrong_ptr = Object.new
        wrong_ptr.define_singleton_method(:to_i) { 0 }
        wrong_ptr.define_singleton_method(:null?) { false }
        ffi_delegate.stub(:wait, ->(*) { wrong_ptr }) do
          CZMQ::FFI::Errors.stub(:errno, Errno::EPERM::Errno) do
            assert_raises(SystemCallError) { poller.wait(0) }
          end
        end
      end
    end
  end

  describe '#ignore_interrupts' do
    it 'tells zpoller to ignore interrupts' do
      called = false
      ffi_delegate.stub(:ignore_interrupts, -> { called = true }) do
        poller.ignore_interrupts
      end
      assert called
    end
  end

  describe '#nonstop=' do
    describe 'with true' do
      it 'tells zpoller to set nonstop flag' do
        called_with = nil
        ffi_delegate.stub(:set_nonstop, ->(flag) { called_with = flag }) do
          poller.nonstop = true
        end
        assert_equal true, called_with
      end
    end
    describe 'with false' do
      it 'tells zpoller to set nonstop flag' do
        called_with = nil
        ffi_delegate.stub(:set_nonstop, ->(flag) { called_with = flag }) do
          poller.nonstop = false
        end
        assert_equal false, called_with
      end
    end
  end
end
