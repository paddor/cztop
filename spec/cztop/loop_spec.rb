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
      let(:socket) { ::FFI::Pointer::NULL }
      it "raises" do
        assert_raises { subject.add_reader(socket) { } }
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

    it "remembers timer" do
      expect(subject).to receive(:remember_timer).
        with(kind_of(CZTop::Loop::SimpleTimer))
      timer
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

  end

  describe "#ticket_delay" do

  end

  describe "#start" do
    it "starts loop" do
      expect(ffi_delegate).to receive(:start)
      subject.start
    end
  end

  describe CZTop::Loop::Timer do
    describe "#initialize"
    describe "#retain_reference"
    describe "#loop"
    describe "#id"
  end

  describe CZTop::Loop::SimpleTimer do
    let(:delay) { 1000 }
    let(:times) { 1 }
    let(:block) { ->{} }
    let(:timer) { described_class.new(delay, times, subject, &block) }

    it "inherits from Timer" do
      assert_operator described_class, :<, CZTop::Loop::Timer
    end

    describe "#initialize" do
      it "remembers delay" do
        assert_equal delay, timer.delay
      end
      it "remembers times" do
        assert_equal times, timer.times
      end
    end

    describe "handler" do
      let(:loop_ptr) { subject.ffi_delegate.__ptr }
      let(:timer_id) { timer.id }
      let(:arg) { nil }
      let(:block) { ->(*yielded) { @yielded=yielded; @called ||= 0; @called += 1 } }
      let(:handler) { timer.instance_variable_get(:@handler) }

      before(:each) { handler.call(loop_ptr, timer_id, arg) }
      it "yields block" do
        assert_equal 1, @called
      end

      it "yields itself" do
        assert_equal 1, @yielded.size
        assert_same timer, @yielded.first
      end
    end

    describe "#register" do
      it "registers simple timer" do
        expect(ffi_delegate).to receive(:timer)
          .with(delay, 1, kind_of(FFI::Function), nil)
          .and_call_original
        timer
      end
      context "when it fails" do
        before(:each) do
          expect(ffi_delegate).to receive(:timer).and_return(-1)
        end
        it "raises" do
          assert_raises(CZTop::Loop::Error) { timer }
        end
      end
    end

    describe "#cancel" do
      it "cancels timer" do
        expect(ffi_delegate).to receive(:timer_end).with(timer.id)
        timer.cancel
      end

      it "removes it from the loop" do
        expect(subject).to receive(:forget_timer).with(timer)
        timer.cancel
      end
    end
  end

  describe CZTop::Loop::TicketTimer do
    it "inherits from Timer" do
      assert_operator described_class, :<, CZTop::Loop::Timer
    end

    describe "#initialize" do

    end

    describe "#cancel" do

    end
  end
end
