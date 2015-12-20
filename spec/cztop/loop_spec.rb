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

  end

  describe "#every" do

  end

  describe "#remember_timer" do

  end

  describe "#forget_timer" do

  end

  describe "#add_ticket_timer" do

  end

  describe "#ticket_delay" do

  end

  describe "#start" do

  end

  describe CZTop::Loop::SimpleTimer do
    describe "#cancel" do

    end
  end

  describe CZTop::Loop::TicketTimer do
    describe "#cancel" do

    end
  end
end
