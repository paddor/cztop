require_relative 'spec_helper'

describe CZTop::Loop do
  include_examples "has FFI delegate"

  subject { CZTop::Loop.new }
  let(:ffi_delegate) { subject.ffi_delegate }
  let(:socket) { CZTop::Socket::REQ.new }

  context "with new loop" do
    describe "#handlers" do
      it "is a hash" do
        assert_kind_of Hash, subject.handlers
      end

      it "is empty" do
        assert_empty subject.handlers
      end
    end
  end

  describe "#add_reader" do
    context "with socket" do
      it "adds reader" do
        expect(ffi_delegate).to receive(:reader)
          .with(socket.ffi_delegate, kind_of(::FFI::Function), nil)
          .and_call_original
        subject.add_reader(socket) { }
      end

      it "remembers handler" do
        assert_equal 0, subject.handlers.size
        subject.add_reader(socket) { }
        assert_equal 1, subject.handlers.size
      end
    end
    context "with wrong socket" do
      before(:each) do
        allow(ffi_delegate).to receive(:reader).and_return(-1)
        allow(CZMQ::FFI::Errors).to receive(:errno).and_return(Errno::EPERM::Errno)
      end
      it "raises" do
        assert_raises(Errno::EPERM) { subject.add_reader(socket) { } }
      end
    end
    context "with no block" do
      it "raises" do
        assert_raises(ArgumentError) { subject.add_reader(socket) }
      end
    end
  end

  describe "#remove_reader" do
    before(:each) do
      subject.add_reader(socket) { }
      subject.add_reader(socket) { }
      assert_equal 1, subject.handlers.size
      assert_equal 2, subject.handlers[socket].size
    end

    it "removes socket from loop" do
      expect(ffi_delegate).to receive(:reader_end)
        .with(socket.ffi_delegate)
        .and_call_original
      subject.remove_reader(socket)
    end

    it "removes handlers for a socket" do
      subject.remove_reader(socket)
      assert_empty subject.handlers[socket]
    end
  end

  describe "#tolerate_reader" do
    it "sets socket tolerant" do
      expect(ffi_delegate).to receive(:reader_set_tolerant)
        .with(socket.ffi_delegate)
        .and_call_original
      subject.tolerate_reader(socket)
    end
  end

  describe "#after" do
    let(:timer) { subject.after(600) {} }

    it "registers timer" do
      expect_any_instance_of(CZTop::Loop::SimpleTimer).to receive(:register)
      assert_equal 1, timer.times
    end

    it "returns SimpleTimer" do
      assert_kind_of CZTop::Loop::SimpleTimer, timer
    end

    context "with explicit number of times" do
      it "passes number of times" do
        timer = subject.after(300, times: 5) {}
        assert_equal 5, timer.times
      end
    end
  end

  describe "#every" do
    let(:timer) { subject.every(500) {} }

    it "registers timer" do
      expect_any_instance_of(CZTop::Loop::SimpleTimer).to receive(:register)
      assert_equal 0, timer.times
    end

    it "returns SimpleTimer" do
      assert_kind_of CZTop::Loop::SimpleTimer, timer
    end

  end

  describe "#remember_timer" do
    let(:id) { double("timer id") }
    let(:timer) { double("timer", id: id) }
    it "adds timer to list" do
      subject.remember_timer(timer)
      assert_equal 1, subject.timers.size
      assert_same timer, subject.timers[id]
    end
  end

  describe "#forget_timer" do
    let(:id) { double("timer id") }
    let(:timer) { double("timer", id: id) }
    before(:each) do
      subject.remember_timer(timer)
      assert_equal 1, subject.timers.size
    end

    it "forgets timer" do
      subject.forget_timer(timer)
      assert_equal 0, subject.timers.size
    end
  end

  describe "#add_ticket_timer" do
    context "with no ticket delay set" do
      it "raises" do
        assert_raises(RuntimeError) { subject.add_ticket_timer { } }
      end
    end

    context "with ticket delay set" do
      let(:ticket_delay) { 40 }
      let(:timer) { subject.add_ticket_timer {} }
      before(:each) { subject.ticket_delay = ticket_delay }

      it "registers timer" do
        expect_any_instance_of(CZTop::Loop::TicketTimer).to receive(:register)
        timer
      end

      it "returns TicketTimer" do
        assert_kind_of CZTop::Loop::TicketTimer, timer
      end
    end
  end

  describe "#ticket_delay" do
    context "with delay not set" do
      it "returns nil" do
        assert_nil subject.ticket_delay
      end
    end
    context "with delay set" do
      let(:delay) { 30 }
      let(:current_delay) { subject.ticket_delay }
      before(:each) { subject.ticket_delay = delay }

      it "returns delay" do
        assert_equal delay, current_delay
      end
    end
  end
  describe "#ticket_delay=" do
    let(:new_delay) { 40 }
    it "sets ticket delay" do
      expect(ffi_delegate).to receive(:set_ticket_delay).with(new_delay)
      subject.ticket_delay = new_delay
    end

    context "with wrong ticket delay" do
      before(:each) { subject.ticket_delay = 50 } # 50 > 40
      it "raises" do
        assert_raises(ArgumentError) do
          subject.ticket_delay = new_delay
        end
      end
    end
  end

  describe "#start" do
    it "starts loop" do
      expect(ffi_delegate).to receive(:start)
      subject.start
    end

    it "reraises handler exceptions" do
      expect(subject).to receive(:reraise_handler_exception)
      subject.start
    end
  end

  describe "#reraise_handler_exception" do
    context "with all non-failing handlers" do
      it "doesn't raise" do
        subject.__send__(:reraise_handler_exception) { }
      end

      it "calls its block" do
        called = 0
        subject.__send__(:reraise_handler_exception) { called += 1 }
        assert_equal 1, called
      end
    end
    context "with a failing handler" do
      let(:exception_class) { Class.new(RuntimeError) }
      let(:exception) { exception_class.new }
      it "raises its exception" do
        assert_raises(exception_class) do
          subject.__send__(:reraise_handler_exception) do
            subject.exception = exception
          end
        end
      end
    end
  end

  describe "#nonstop=" do
    after(:each) { subject.nonstop = new_flag }
    context "with true" do
      let(:new_flag) { true }
      it "tells zloop to set nonstop flag" do
        expect(ffi_delegate).to receive(:set_nonstop).with(new_flag)
      end
    end
    context "with true" do
      let(:new_flag) { false }
      it "tells zloop to set nonstop flag" do
        expect(ffi_delegate).to receive(:set_nonstop).with(new_flag)
      end
    end
  end

  describe "integration test" do
    i = 0
    let(:endpoint) { "inproc://loop_spec_#{i+=1}" }
    let(:reader) do
      s = CZTop::Socket::PAIR.new
      s.bind(endpoint)
      s
    end
    let(:writer) do
      s = CZTop::Socket::PAIR.new
      s.connect(endpoint)
      s
    end
    let(:num) { 5 } # number of messages to send/receive
    let(:received_messages) { [] }
    let(:loop) do
      loop = CZTop::Loop.new
      loop.add_reader(reader) do
        received_messages << reader.receive
        -1 if received_messages.size == num
      end
      loop
    end

    context "with readable socket" do
      before(:each) do
        reader
        num.times { writer << "foobar" }
        loop.start
      end
      it "runs handler" do
        assert_equal num, received_messages.size
      end
    end
  end
end
