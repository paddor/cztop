require_relative 'spec_helper'
require 'benchmark'

describe CZTop::Poller do
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

  describe "#initialize" do
    context "with no readers" do
      it "initializes empty" do
        expect_any_instance_of(CZTop::Poller).not_to receive(:add)
      end
    end
    context "with one reader" do
      let(:socket) { reader1 }
      after(:each) { CZTop::Poller.new(socket) }
      it "adds reader" do
        expect_any_instance_of(CZTop::Poller).to receive(:add_reader).with(socket)
      end
    end
    context "with multiple readers" do
      let(:poller) { CZTop::Poller.new(reader1, reader2) }
      it "adds readers" do
        # NOTE:
        # This doesn't work anymore on at least Rubinius 3.28:
        #   expect_any_instance_of(CZTop::Poller).to receive(:add_reader).with(r1)
        #   expect_any_instance_of(CZTop::Poller).to receive(:add_reader).with(r2)
        #
        assert_equal 2, poller.sockets.size
        assert_operator poller.sockets, :include?, reader1
        assert_operator poller.sockets, :include?, reader2
        poller.sockets.each do |socket|
          assert_equal POLLIN, poller.event_mask_for_socket(socket)
        end
      end
    end
  end
  describe "#add" do
    context "with reader" do
      let(:socket) { reader1 }
      after(:each) do
        poller.add(socket, POLLIN)
        assert_includes poller.sockets, reader1 # keeps ref
      end
      it "adds reader socket" do
        expect(CZTop::Poller::ZMQ).to receive(:poller_add).
          with(poller_ptr, socket_ptr, nil, POLLIN).
          and_call_original
      end
    end
    context "with writer" do
      let(:socket) { writer1 }
      after(:each) do
        poller.add(socket, POLLOUT)
        assert_includes poller.sockets, writer1 # keeps ref
      end
      it "adds writer socket" do
        expect(CZTop::Poller::ZMQ).to receive(:poller_add).
          with(poller_ptr, socket_ptr, nil, POLLOUT).
          and_call_original
      end
    end
    context "with non-socket" do
      it "raises" do
        assert_raises(ArgumentError) { poller.add("foo", POLLOUT) }
      end
    end
  end
  describe "#add_reader" do
    after(:each) { poller.add_reader(reader1) }
    it "adds reader" do
      expect(poller).to receive(:add).with(reader1, POLLIN)
    end
  end
  describe "#add_writer" do
    after(:each) { poller.add_writer(writer1) }
    it "adds writer" do
      expect(poller).to receive(:add).with(writer1, POLLOUT)
    end
  end
  describe "#modify" do
    context "with registered socket" do
      let(:socket) { reader1 }
      let(:events) { POLLIN | POLLOUT }
      before(:each) { poller.add_reader(reader1) }
      after(:each) { poller.modify(reader1, events) }
      it "modifies events" do
        expect(CZTop::Poller::ZMQ).to receive(:poller_modify).
          with(poller_ptr, socket_ptr, events).and_call_original
      end
    end
    context "with unregistered socket" do
      it "raises" do
        assert_raises(ArgumentError) { poller.modify(reader1, POLLIN) }
      end
    end
  end
  describe "#remove" do
    context "with registered socket" do
      let(:socket) { reader1 }
      before(:each) { poller.add_reader(socket) }
      after(:each) do
        poller.remove(socket)
        refute_includes poller.sockets, reader1 # forgets ref
      end
      it "removes reader" do
        expect(CZTop::Poller::ZMQ).to receive(:poller_remove).
          with(poller_ptr, socket_ptr).and_call_original
      end
    end
    context "with unregistered reader" do
      it "raises" do
        assert_raises(ArgumentError) { poller.remove(reader1) }
      end
    end
    context "with non-socket" do
      it "raises" do
        assert_raises(ArgumentError) { poller.remove("foo") }
      end
    end
  end
  describe "#remove_reader" do
    context "with socket registered for readability only" do
      let(:socket) { reader1 }
      before(:each) { poller.add_reader(socket) }
      after(:each) do
        poller.remove_reader(socket)
      end
      it "removes reader" do
        expect(poller).to receive(:remove).
          with(socket)
      end
    end
    context "with unregistered reader" do
      it "raises" do
        assert_raises(ArgumentError) { poller.remove_reader(reader1) }
      end
    end
    context "with socket registered for writability" do
      let(:socket) { writer1 }
      before(:each) { poller.add_writer(socket) }
      it "raises" do
        assert_raises(ArgumentError) { poller.remove_reader(socket) }
      end
    end
    context "with socket registered for readability and writability" do
      let(:socket) { CZTop::Socket::DEALER.new(endpoint1) }
      before(:each) { poller.add(socket, POLLIN | POLLOUT) }
      it "raises" do
        assert_raises(ArgumentError) { poller.remove_reader(socket) }
      end
    end
  end
  describe "#remove_writer" do
    context "with socket registered for writability only" do
      let(:socket) { writer1 }
      before(:each) { poller.add_writer(socket) }
      after(:each) do
        poller.remove_writer(socket)
      end
      it "removes writer" do
        expect(poller).to receive(:remove).
          with(socket)
      end
    end
    context "with unregistered writer" do
      it "raises" do
        assert_raises(ArgumentError) { poller.remove_writer(writer1) }
      end
    end
    context "with socket registered for readability" do
      let(:socket) { reader1 }
      before(:each) { poller.add_reader(socket) }
      it "raises" do
        assert_raises(ArgumentError) { poller.remove_writer(socket) }
      end
    end
    context "with socket registered for readability and writability" do
      let(:socket) { CZTop::Socket::DEALER.new(endpoint1) }
      before(:each) { poller.add(socket, POLLIN | POLLOUT) }
      it "raises" do
        assert_raises(ArgumentError) { poller.remove_writer(socket) }
      end
    end
  end
  describe "#wait" do
    context "in general" do
      let(:poller_ptr) { poller.instance_variable_get(:@poller_ptr) }
      let(:event_ptr) { poller.instance_variable_get(:@event_ptr) }

      before(:each) do
        poller.add(reader1, POLLIN)
        poller.add(reader2, POLLIN)
        poller.add(reader3, POLLIN)
        poller.add(writer1, POLLOUT)
        poller.add(writer2, POLLOUT)
        poller.add(writer3, POLLOUT)
      end
      after(:each) { poller.wait(15) }

      it "passes arguments to zmq_poller_wait()" do
        expect(CZTop::Poller::ZMQ).to receive(:poller_wait)
          .with(poller_ptr, event_ptr, 15).and_return(-1)
        allow(CZMQ::FFI::Errors).to receive(:errno)
          .and_return(Errno::ETIMEDOUT::Errno)
      end
    end

    context "with no registered sockets" do
      it "doesn't raise" do
        poller.wait(0)
      end
    end

    context "with readable socket" do
      before(:each) do
        writer1 << "foobar"
        poller.add(reader1, POLLIN)
      end
      it "returns first readable socket" do
        assert_same reader1, event.socket
        assert_operator event, :readable?
      end
    end
    context "with no readable socket" do
      before(:each) do
        poller.add(reader1, POLLIN)
      end
      it "returns nil" do
        assert_nil poller.wait(20)
      end
    end

    context "with thread-safe sockets", skip: zmq_version?("4.2") do
      i = 0
      let(:endpoint) { "inproc://poller_spec_srv_client_#{i += 1}" }
      let(:server) { CZTop::Socket::SERVER.new(endpoint) }
      let(:client) { CZTop::Socket::CLIENT.new(endpoint) }
      let(:poller) { CZTop::Poller.new(server) }

      context "with message from client" do
        before(:each) do
          client << "foobar"
        end
        it "makes server socket readable" do
          assert_same server, event.socket
          assert_operator event, :readable?
        end
      end
    end
  end

  describe "#simple_wait" do
    context "with event" do
      before(:each) do
        writer1 << "foobar"
        poller.add_reader(reader1)
      end
      it "returns socket" do
        assert_same reader1, poller.simple_wait(20)
      end
    end
    context "with timeout expired" do
      before(:each) do
        poller.add_reader(reader1)
      end
      it "returns nil" do
        assert_nil poller.simple_wait(20)
      end
    end
  end

  describe "with actor" do
    let(:actor) do # echo actor
      CZTop::Actor.new { |msg, pipe| pipe << msg }
    end

    before(:each) do
      poller.add_reader(actor)
    end
    after(:each) do
      actor.terminate
    end

    context "with unreadable actor" do
      it "returns nil" do
        assert_nil poller.wait(20)
      end
    end
    context "with readable actor" do
      before(:each) { actor << "foo" }
      it "returns actor" do
        assert_same actor, event.socket
      end
    end
  end

  describe "#socket_for_ptr" do
    let(:socket) { reader1 }
    context "with known pointer" do
      before(:each) { poller.add_reader(socket) }
      it "returns socket" do
        assert_same socket, poller.socket_for_ptr(socket_ptr)
      end
    end
    context "with unknown pointer" do
      it "raises" do
        assert_raises(ArgumentError) do
          poller.socket_for_ptr(socket_ptr)
        end
      end
    end
  end

  describe "#sockets" do
    context "with no registered sockets" do
      it "returns empty array" do
        assert_equal [], poller.sockets
      end
    end
    context "with registered sockets" do
      before(:each) do
        poller.add_reader(reader1)
        poller.add_writer(writer2)
      end
      it "returns registered sockets" do
        assert_equal [reader1, writer2], poller.sockets
      end
    end
  end

  describe "#event_mask_for_socket" do
    context "for registered reader socket" do
      before(:each) { poller.add_reader(reader1) }
      it "returns event mask" do
        assert_equal POLLIN, poller.event_mask_for_socket(reader1)
      end
    end
    context "for registered writer socket" do
      before(:each) { poller.add_writer(writer1) }
      it "returns event mask" do
        assert_equal POLLOUT, poller.event_mask_for_socket(writer1)
      end
    end
    context "for registered reader/writer socket (in 1 step)" do
      let(:socket) { CZTop::Socket::DEALER.new(endpoint1) }
      before(:each) do
        poller.add(socket, POLLIN | POLLOUT)
      end
      it "returns event mask" do
        assert_equal POLLIN|POLLOUT, poller.event_mask_for_socket(socket)
      end
    end

    context "for unregistered socket" do
      it "raises" do
        assert_raises(ArgumentError) do
          poller.event_mask_for_socket(reader1)
        end
      end
    end
  end

  describe CZTop::Poller::Aggregated do
    let(:poller) { CZTop::Poller.new }
    let(:aggpoller) { CZTop::Poller::Aggregated.new(poller) }

    describe "#poller" do
      it "returns associated CZTop::Poller" do
        assert_same poller, aggpoller.poller
      end
    end

    describe "#wait" do
      context "when building lists" do
        let(:readables_before) { aggpoller.readables }
        let(:writables_before) { aggpoller.writables }
        before(:each) do
          readables_before
          writables_before
          aggpoller.wait(0)
        end
        it "builds completely new lists" do # forgetting the previous ones
          refute_same readables_before, aggpoller.readables
          refute_same writables_before, aggpoller.writables
        end
      end

      context "when calling CZTop::Poller#wait" do
        let(:timeout) { 11 }
        after(:each) { aggpoller.wait(timeout) }
        it "passes timeout" do
          expect(poller).to receive(:wait).with(timeout).and_call_original
        end
      end

      context "with new event" do
        before(:each) do
          writer1 << "foobar"
          poller.add_reader(reader1)
        end
        it "returns true" do
          assert aggpoller.wait(20)
        end
      end
      context "with no event" do
        it "returns false" do
          refute aggpoller.wait(0)
        end
      end

      context "having been called previously" do
        before(:each) do
          writer1 << "i'll teach you how to read"
          poller.add_reader(reader1)
          poller.add_writer(writer1)
          aggpoller.wait(20)
          assert_includes aggpoller.readables, reader1
        end
        it "is level-triggered" do # recognizes the socket as readable again
          aggpoller.wait(0)
          assert_includes aggpoller.readables, reader1
        end
      end
    end
    describe "#readables" do
      it "returns array" do
        assert_kind_of Array, aggpoller.readables
      end
      context "with no previous call to #wait" do
        it "returns empty array" do
          assert_equal [], aggpoller.readables
        end
      end
      context "with readable and unreadable socket" do
        before(:each) do
          writer1 << "foobar"
          poller.add_reader(reader1) # readable
          poller.add_reader(reader2) # unreadable
          poller.add_writer(writer1) # a writer
          aggpoller.wait(20)
        end
        it "returns readable socket" do
          assert_equal [reader1], aggpoller.readables
        end
      end
    end
    describe "#writables" do
      it "returns array" do
        assert_kind_of Array, aggpoller.writables
      end
      context "with no previous call to #wait" do
        it "returns empty array" do
          assert_equal [], aggpoller.writables
        end
      end
      context "with writable and unwritable sockets" do

        let(:writable) { CZTop::Socket::DEALER.new(endpoint1) }
        let(:unwritable) do
          s = CZTop::Socket::DEALER.new # an unconnected socket is not writable
          s.options.sndtimeo = 10 # don't block forever
          s
        end
        before(:each) do
          poller.add_writer(writable) # writable
          poller.add_writer(unwritable) # unwritable
          poller.add_reader(reader3) # a reader
          aggpoller.wait(20)
        end
        it "returns writable socket" do
          assert_equal [writable], aggpoller.writables
        end
      end
    end
    describe "forwarded methods" do
      let(:obj) { Object.new }
      describe "#add" do
        after(:each) { assert_equal :foo, aggpoller.add(obj) }
        it "forwards to Poller" do
          expect(poller).to receive(:add).with(obj).and_return(:foo)
        end
      end
      describe "#add_reader" do
        after(:each) { assert_equal :foo, aggpoller.add_reader(obj) }
        it "forwards to Poller" do
          expect(poller).to receive(:add_reader).with(obj).and_return(:foo)
        end
      end
      describe "#add_writer" do
        after(:each) { assert_equal :foo, aggpoller.add_writer(obj) }
        it "forwards to Poller" do
          expect(poller).to receive(:add_writer).with(obj).and_return(:foo)
        end
      end
      describe "#modify" do
        after(:each) { assert_equal :foo, aggpoller.modify(obj) }
        it "forwards to Poller" do
          expect(poller).to receive(:modify).with(obj).and_return(:foo)
        end
      end
      describe "#remove" do
        after(:each) { assert_equal :foo, aggpoller.remove(obj) }
        it "forwards to Poller" do
          expect(poller).to receive(:remove).with(obj).and_return(:foo)
        end
      end
      describe "#remove_reader" do
        after(:each) { assert_equal :foo, aggpoller.remove_reader(obj) }
        it "forwards to Poller" do
          expect(poller).to receive(:remove_reader).with(obj).and_return(:foo)
        end
      end
      describe "#remove_writer" do
        after(:each) { assert_equal :foo, aggpoller.remove_writer(obj) }
        it "forwards to Poller" do
          expect(poller).to receive(:remove_writer).with(obj).and_return(:foo)
        end
      end
      describe "#sockets" do
        after(:each) { assert_equal :foo, aggpoller.sockets(obj) }
        it "forwards to Poller" do
          expect(poller).to receive(:sockets).with(obj).and_return(:foo)
        end
      end
    end
  end
end

describe CZTop::Poller::ZPoller do
  include_examples "has FFI delegate"

  let(:poller) { CZTop::Poller::ZPoller.new(reader1) }
  let(:ffi_delegate) { poller.ffi_delegate }
  i = 0
  let(:reader1) { CZTop::Socket::PULL.new("inproc://zpoller_spec_r1_#{i += 1}") }
  let(:reader2) { CZTop::Socket::PULL.new("inproc://zpoller_spec_r2_#{i += 1}") }
  let(:reader3) { CZTop::Socket::PULL.new("inproc://zpoller_spec_r3_#{i += 1}") }

  describe "#initialize" do
    after(:each) { poller }

    context "with one reader" do
      it "passes reader" do
        expect(CZMQ::FFI::Zpoller).to receive(:new)
          .with(reader1, :pointer, nil).and_call_original
      end
      it "remembers the reader" do
        expect_any_instance_of(CZTop::Poller::ZPoller).to receive(:remember_socket)
          .with(reader1)
        poller
      end
    end
    context "with additional readers" do
      let(:poller) { CZTop::Poller::ZPoller.new(reader1, reader2, reader3) }
      it "passes all readers" do
        expect(CZMQ::FFI::Zpoller).to receive(:new)
          .with(reader1, :pointer, reader2, :pointer, reader3, :pointer, nil)
          .and_call_original
      end
      it "remembers all readers" do
        expect_any_instance_of(CZTop::Poller::ZPoller).to receive(:remember_socket)
          .with(reader1)
        expect_any_instance_of(CZTop::Poller::ZPoller).to receive(:remember_socket)
          .with(reader2)
        expect_any_instance_of(CZTop::Poller::ZPoller).to receive(:remember_socket)
          .with(reader3)
      end
    end
  end

  describe "#add" do
    it "adds reader" do
      expect(ffi_delegate).to receive(:add).with(reader2).and_call_original
      poller.add(reader2)
    end
    it "remembers the reader" do
      expect(poller).to receive(:remember_socket).with(reader2)
        .and_call_original
      poller.add(reader2)
    end
    context "with failure" do
      before(:each) do
        allow(ffi_delegate).to receive(:add).and_return(-1)
        allow(CZMQ::FFI::Errors).to receive(:errno)
          .and_return(Errno::EPERM::Errno)
      end
      it "raises" do
        assert_raises(SystemCallError) { poller.add(reader2) }
      end
    end
  end
  describe "#remove" do
    it "removes reader" do
      expect(ffi_delegate).to receive(:remove).with(reader1)
        .and_call_original
      poller.remove(reader1)
    end
    it "forgets the reader" do
      expect(poller).to receive(:forget_socket).with(reader1)
        .and_call_original
      poller.remove(reader1)
    end
    context "with failure" do
      before(:each) do
        allow(ffi_delegate).to receive(:remove).and_return(-1)
        allow(CZMQ::FFI::Errors).to receive(:errno)
          .and_return(Errno::EPERM::Errno)
      end
      it "raises" do
        assert_raises(SystemCallError) { poller.remove(reader2) }
      end
    end
    context "with unknown socket" do
      it "raises" do
        assert_raises(ArgumentError) { poller.remove(reader2) }
      end
    end
  end
  describe "#wait" do
    context "with readable socket" do
      before(:each) do
        CZTop::Socket::PUSH.new(reader1.last_endpoint) << "foo"
      end
      it "returns socket" do
        assert_same reader1, poller.wait
      end
    end
    context "with expired timeout" do
      it "returns nil" do
        assert_nil poller.wait(0)
      end
    end
    context "with interrupt" do
      before(:each) do
        allow(ffi_delegate).to receive(:terminated).and_return(true)
      end
      it "raises Interrupt" do
        assert_raises(Interrupt) do
          poller.wait(0)
        end
      end
    end

    it "the timeout is in ms" do
      duration = Benchmark.realtime { poller.wait(30) }
      assert_in_delta 0.03, duration, 0.02 # +- 20ms is OK
    end

    context "with no timeout" do
      after(:each) { poller.wait }
      it "waits indefinitely" do
        expect(ffi_delegate).to receive(:wait).with(-1)
          .and_return(FFI::Pointer::NULL)
      end
    end

    context "with wrong pointer from zpoller_wait" do
      let(:wrong_ptr) { double("pointer", to_i: 0, null?: false) }
      before(:each) do
        allow(ffi_delegate).to receive(:wait).and_return(wrong_ptr)
        allow(CZMQ::FFI::Errors).to receive(:errno)
          .and_return(Errno::EPERM::Errno)
      end
      it "raises" do # instead of returning nil
        assert_raises(SystemCallError) { poller.wait(0) }
      end
    end
  end
  describe "#ignore_interrupts" do
    after(:each) { poller.ignore_interrupts }
    it "tells zpoller to ignore interrupts" do
      expect(ffi_delegate).to receive(:ignore_interrupts)
    end
  end
  describe "#nonstop=" do
    after(:each) { poller.nonstop = new_flag }
    context "with true" do
      let(:new_flag) { true }
      it "tells zpoller to set nonstop flag" do
        expect(ffi_delegate).to receive(:set_nonstop).with(new_flag)
      end
    end
    context "with true" do
      let(:new_flag) { false }
      it "tells zpoller to set nonstop flag" do
        expect(ffi_delegate).to receive(:set_nonstop).with(new_flag)
      end
    end
  end
end
