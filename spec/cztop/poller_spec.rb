require_relative 'spec_helper'
require 'benchmark'

describe CZTop::Poller do
  include_examples "has FFI delegate"

  let(:poller) { CZTop::Poller.new(reader1) }
  let(:ffi_delegate) { poller.ffi_delegate }
  i = 57578
  let(:reader1) { CZTop::Socket::PULL.new("inproc://poller_spec_r1_#{i += 1}") }
  let(:reader2) { CZTop::Socket::PULL.new("inproc://poller_spec_r2_#{i += 1}") }
  let(:reader3) { CZTop::Socket::PULL.new("inproc://poller_spec_r3_#{i += 1}") }


  describe "#initialize" do
    after(:each) { poller }

    context "with one reader" do
      it "passes reader" do
        expect(CZMQ::FFI::Zpoller).to receive(:new)
          .with(reader1, :pointer, nil).and_call_original
      end
      it "remembers the reader" do
        expect_any_instance_of(CZTop::Poller).to receive(:remember_socket)
          .with(reader1)
        poller
      end
    end
    context "with additional readers" do
      let(:poller) { CZTop::Poller.new(reader1, reader2, reader3) }
      it "passes all readers" do
        expect(CZMQ::FFI::Zpoller).to receive(:new)
          .with(reader1, :pointer, reader2, :pointer, reader3, :pointer, nil)
          .and_call_original
      end
      it "remembers all readers" do
        expect_any_instance_of(CZTop::Poller).to receive(:remember_socket)
          .with(reader1)
        expect_any_instance_of(CZTop::Poller).to receive(:remember_socket)
          .with(reader2)
        expect_any_instance_of(CZTop::Poller).to receive(:remember_socket)
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
      assert_in_delta 0.03, duration, 0.01
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
