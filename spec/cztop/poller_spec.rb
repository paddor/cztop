require_relative 'spec_helper'
require 'benchmark'

describe CZTop::Poller do
  let(:poller) { CZTop::Poller.new }

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

  describe "#initialize" do
    context "with no readers" do
      it "initializes empty" do
        assert_empty poller.readers
        assert_empty poller.writers
      end

      it "schedules rebuild" do
        assert poller.instance_variable_get(:@rebuild_needed)
      end
    end
    context "with one reader" do
      let(:poller) { CZTop::Poller.new(reader1) }
      it "adds reader" do
        assert_includes poller.readers, reader1
      end
    end
    context "with multiple readers" do
      let(:poller) { CZTop::Poller.new(reader1, reader2) }
      it "adds readers" do
        assert_includes poller.readers, reader1
        assert_includes poller.readers, reader2
      end
    end
  end
  describe "#readers" do
    it "returns array" do
      assert_kind_of Array, poller.readers
    end
  end
  describe "#writers" do
    it "returns array" do
      assert_kind_of Array, poller.writers
    end
  end
  describe "#add_reader" do
    before(:each) { poller.add_reader(reader1) }
    it "adds reader socket" do
      assert_includes poller.readers, reader1
    end
    it "schedules rebuild" do
      poller.wait(0) # ensure that no rebuild is scheduled
      refute poller.instance_variable_get(:@rebuild_needed)
      poller.add_reader(reader2)
      assert poller.instance_variable_get(:@rebuild_needed)
    end
    context "with non-socket" do
      it "raises" do
        assert_raises(ArgumentError) { poller.add_reader("foo") }
      end
    end
  end
  describe "#remove_reader" do
    context "with registered reader" do
      before(:each) do
        poller.add_reader(reader1)
        poller.wait(0) # ensure that no rebuild is scheduled
        poller.remove_reader(reader1)
      end
      it "removes reader" do
        refute_includes poller.readers, reader1
      end
      it "schedules rebuild" do
        assert poller.instance_variable_get(:@rebuild_needed)
      end
    end
    context "with unregistered reader" do
      before(:each) do
        poller.wait(0) # ensure that no rebuild is scheduled
        poller.remove_reader(reader1)
      end
      it "doesn't raise" do end
      it "doesn't schedule rebuild" do
        refute poller.instance_variable_get(:@rebuild_needed)
      end
    end
    context "with non-socket" do
      it "raises" do
        assert_raises(ArgumentError) { poller.remove_reader("foo") }
      end
    end
  end
  describe "#add_writer" do
    before(:each) { poller.add_writer(writer1) }
    it "adds writer socket" do
      assert_includes poller.writers, writer1
    end
    it "schedules rebuild" do
      poller.wait(0) # ensure that no rebuild is scheduled
      refute poller.instance_variable_get(:@rebuild_needed)
      poller.add_writer(writer2)
      assert poller.instance_variable_get(:@rebuild_needed)
    end
    context "with non-socket" do
      it "raises" do
        assert_raises(ArgumentError) { poller.add_writer("foo") }
      end
    end
  end
  describe "#remove_writer" do
    context "with registered writer" do
      before(:each) do
        poller.add_writer(writer1)
        poller.wait(0) # ensure that no rebuild is scheduled
        poller.remove_writer(writer1)
      end
      it "removes writer" do
        refute_includes poller.writers, writer1
      end
      it "schedules rebuild" do
        assert poller.instance_variable_get(:@rebuild_needed)
      end
    end
    context "with unregistered writer" do
      before(:each) do
        poller.wait(0) # ensure that no rebuild is scheduled
        poller.remove_writer(writer1)
      end
      it "doesn't raise" do end
      it "doesn't schedule rebuild" do
        refute poller.instance_variable_get(:@rebuild_needed)
      end
    end
    context "with non-socket" do
      it "raises" do
        assert_raises(ArgumentError) { poller.remove_writer("foo") }
      end
    end
  end

  describe "#wait" do
    context "with no registered sockets" do
      it "doesn't raise" do
        poller.wait(0)
      end
    end

    context "having called previously" do
      before(:each) do
        writer1 << "i'll teach you how to read"
        poller.add_reader(reader1)
        poller.add_writer(writer1)
        poller.wait(20)
        assert_includes poller.readables, reader1
        readers_before # remember current object
        writers_before # remember current object
      end
      let(:readers_before) { poller.readables }
      let(:writers_before) { poller.writables }
      it "forgets readable and writable sockets" do
        reader1.receive # empty it
        poller.wait(0)
        refute_same readers_before, poller.readables
        refute_same writers_before, poller.writers
      end
      it "is level-triggered" do # recognizes the socket as readable again
        poller.wait(0)
        assert_includes poller.readables, reader1
      end
    end
    context "when rebuild is not needed" do
      before(:each) do
        poller.add_reader(reader1)
        poller.wait(0)
      end
      it "doesn't rebuild" do
        expect(poller).not_to receive(:rebuild)
      end
      after(:each) { poller.wait(0) }
    end
    context "when rebuild is needed" do
      before(:each) do
        poller.add_reader(reader1)
        poller.wait(0)
        poller.add_reader(reader2)
      end
      it "rebuilds" do
        expect(poller).to receive(:rebuild).and_call_original
      end
      after(:each) { poller.wait(0) }
    end

    context "with timeout" do
      let(:timeout) { 22 }
      before(:each) do
        poller.add_reader(reader1)
        poller.add_reader(reader2)
        poller.add_reader(reader3)
        poller.add_writer(reader1)
        poller.add_writer(reader2)
        poller.add_writer(reader3)
      end
      it "calls zmq_poll" do
        expect(CZTop::Poller::ZMQ).to receive(:poll)
          .with(FFI::Pointer, 6, timeout).and_return(0)
      end
      after(:each) { poller.wait(timeout) }
    end

    context "with readable socket" do
      before(:each) do
        writer1 << "foobar"
        poller.add_reader(reader1)
      end
      it "returns first readable socket" do
        assert_same reader1, poller.wait(20)
      end
    end
    context "with no readable socket" do
      before(:each) do
        poller.add_reader(reader1)
      end
      it "returns nil" do
        assert_nil poller.wait(20)
      end
    end
    context "with readable SERVER socket", skip: czmq_function?(:zsock_new_server) do
      let(:server) { CZTop::Socket::SERVER.new(endpoint1) }
      let(:client) { CZTop::Socket::CLIENT.new(endpoint1) }
      before(:each) do
        client << "hello"
        poller.add_reader(server)
      end
      it "raises" do
        assert_raises(ArgumentError) { poller.wait(0) }
      end
    end
  end

  describe "#readables" do
    context "with no previous call to #wait" do
      it "returns empty array" do
        assert_equal [], poller.readables
      end
    end
    context "with readable and unreadable socket" do
      before(:each) do
        writer1 << "foobar"
        poller.add_reader(reader1) # readable
        poller.add_reader(reader2) # unreadable
        poller.add_writer(writer1) # a writer
        poller.wait(20)
      end
      it "returns array" do
        assert_kind_of Array, poller.readables
      end
      it "returns readable socket" do
        assert_equal [reader1], poller.readables
      end
      it "memoizes" do
        assert_same poller.readables, poller.readables
      end
    end
  end
  describe "#writables" do
    context "with no previous call to #wait" do
      it "returns empty array" do
        assert_equal [], poller.writables
      end
    end
    context "with writable and unwritable socket" do

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
        poller.wait(20)
      end
      it "returns array" do
        assert_kind_of Array, poller.writables
      end
      it "returns writable socket" do
        assert_equal [writable], poller.writables
      end
      it "memoizes" do
        assert_same poller.writables, poller.writables
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
        assert_same actor, poller.wait(20)
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
    context "with unknown socket", skip: czmq_feature?(
      "errors from zpoller_remove()", :zcert_unset_meta) do

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
