require_relative 'spec_helper'

describe CZTop::Poller do
  include_examples "has FFI delegate"

  let(:poller) { CZTop::Poller.new(reader1) }
  let(:ffi_delegate) { poller.ffi_delegate }
  i = 57578
  let(:reader1) { CZTop::Socket::PULL.new("inproc://poller_spec_#{i += 1}") }
  let(:reader2) { CZTop::Socket::PULL.new("inproc://poller_spec_#{i += 1}") }
  let(:reader3) { CZTop::Socket::PULL.new("inproc://poller_spec_#{i += 1}") }

  describe "#initialize" do
    after(:each) { poller }
    context "with one reader" do
      it "passes reader" do
        expect(CZMQ::FFI::Zpoller).to receive(:new)
          .with(reader1, any_args).and_call_original
      end
    end
    context "with more readers" do
      let(:poller) { CZTop::Poller.new(reader1, reader2, reader3) }
      it "adds the other readers" do
        expect_any_instance_of(CZTop::Poller).to receive(:add)
          .with(reader2).and_call_original
        expect_any_instance_of(CZTop::Poller).to receive(:add)
          .with(reader3).and_call_original
      end
    end
  end

  describe "#add" do
    it "adds reader" do
      expect(ffi_delegate).to receive(:add).with(reader2)
      poller.add(reader2)
    end
    context "with failure" do
      before(:each) do
        allow(ffi_delegate).to receive(:add).and_return(-1)
      end
      it "raises" do
        assert_raises(CZTop::Poller::Error) { poller.add(reader2) }
      end
    end
  end
  describe "#remove" do
    it "removes reader" do
      expect(ffi_delegate).to receive(:remove).with(reader2)
      poller.remove(reader2)
    end
    context "with failure" do
      before(:each) do
        allow(ffi_delegate).to receive(:remove).and_return(-1)
      end
      it "raises" do
        assert_raises(CZTop::Poller::Error) { poller.remove(reader2) }
      end
    end
    context "with unknown socket" do
      it "raises" do
        assert_raises(CZTop::Poller::Error) { poller.remove(reader2) }
      end
    end
  end
  describe "#wait" do

  end
  describe "#expired?" do

  end
  describe "#terminated?" do

  end
  describe "#ignore_interrupts" do

  end
end
