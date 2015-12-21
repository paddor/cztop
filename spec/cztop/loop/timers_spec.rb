require_relative '../spec_helper'

describe CZTop::Loop do

  subject { CZTop::Loop.new }
  let(:ffi_delegate) { subject.ffi_delegate }
  let(:socket) { CZTop::Socket::REQ.new }

  describe CZTop::Loop::Timer do
    let(:timer_class) do
      Class.new(described_class) do
        def initialize(loop, &blk) @loop, @proc = loop, blk; @id = 666; super() end
        def register; @registered = true end
        def registered?() @registered end
      end
    end
    let(:timer) { timer_class.new(subject) {} }

    describe "#initialize" do
      it "calls #register" do
        assert_operator timer, :registered?
      end
      it "retains reference" do
        timer
        assert_same timer, subject.timers[timer.id]
      end
    end

    describe "#call" do
      it "calls timer's proc" do
        called = 0
        timer = timer_class.new(subject) { called += 1 }
        assert_equal 0, called
        timer.call
        assert_equal 1, called
      end

      it "yields self" do
        yielded = nil
        timer = timer_class.new(subject) { |o| yielded = o }
        timer.call
        assert_same timer, yielded
      end

      context "with non-failing proc" do
        it "returns 0" do
          assert_equal 0, timer.call
        end
      end

      context "with failing proc" do
        let(:exception) { RuntimeError.new("foobar") }
        let(:timer) { timer_class.new(subject) { raise exception } }
        it "registers exception" do
          assert_nil subject.exception
          timer.call
          assert_same exception, subject.exception
        end

        it "returns -1" do
          assert_equal -1, timer.call
        end
      end
    end
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
      it "remembers loop" do
        assert_same subject, timer.loop
      end
      it "has an ID" do
        assert_kind_of Integer, timer.id
      end
    end

    describe "handler" do
      let(:loop_ptr) { subject.ffi_delegate.__ptr }
      let(:timer_id) { timer.id }
      let(:arg) { nil }
      let(:block) { ->{ } }
      let(:handler) { timer.instance_variable_get(:@handler) }

      context "when called" do
        it "calls #call" do
          expect(timer).to receive(:call).and_return(0)
          handler.call(loop_ptr, timer_id, arg)
        end
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
    let(:delay) { 50 }
    let(:block) { ->{} }
    let(:timer) { described_class.new(subject, &block) }
    before(:each) { subject.ticket_delay = delay }

    it "inherits from Timer" do
      assert_operator described_class, :<, CZTop::Loop::Timer
    end

    describe "#initialize" do

      it "remembers loop" do
        assert_same subject, timer.loop
      end
      it "has an ID" do
        assert_equal 0, timer.id
      end
    end

    describe "#cancel" do
      let(:ptr) { timer.instance_variable_get(:@ptr) }
      it "cancels timer" do
        expect(ffi_delegate).to receive(:ticket_delete).with(ptr)
        timer.cancel
      end

      it "removes it from the loop" do
        expect(subject).to receive(:forget_timer).with(timer)
        timer.cancel
      end
    end

    describe "handler" do
      let(:loop_ptr) { subject.ffi_delegate.__ptr }
      let(:timer_id) { 0 } # timer ID for tickets
      let(:arg) { nil }
      let(:block) { ->{} }
      let(:handler) { timer.instance_variable_get(:@handler) }

      context "when called" do
        it "calls #call" do
          expect(timer).to receive(:call).and_return(0)
          handler.call(loop_ptr, timer_id, arg)
        end
      end
    end
  end
end
