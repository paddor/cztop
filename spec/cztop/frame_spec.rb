require_relative '../spec_helper'

describe CZTop::Frame do

  describe ".send_to" do
    Given(:frame) { CZTop::Frame.new }
    Given(:socket) { double() } # doesn't matter
    it "delegates it to CZMQ::FFI" do
      expect(CZMQ::FFI::Zframe).to receive(:send)
      frame.send_to(socket)
    end
    describe "with MORE option set" do
      it "provides correct flags" do
        provided_flags = nil
        expect(CZMQ::FFI::Zframe).to receive(:send) do |_,_,flags|
          provided_flags = flags
        end.and_return(0)
        frame.send_to(socket, more: true)
        assert_operator CZTop::Frame::FLAG_MORE & provided_flags, :>, 0
      end
    end
    describe "with DONTWAIT set" do
      it "provides correct flags" do
        provided_flags = nil
        expect(CZMQ::FFI::Zframe).to receive(:send) do |_,_,flags|
          provided_flags = flags
        end.and_return(0)
        frame.send_to(socket, dontwait: true)
        assert_operator CZTop::Frame::FLAG_DONTWAIT & provided_flags, :>, 0
      end

      describe "when it can't send right now" do
        Given(:socket) { CZTop::Socket.new_by_type(:DEALER) }
        When(:result) { frame.send_to(socket, dontwait: true) }
        Then { result == Failure(IO::EAGAINWaitWritable) }
      end
    end
    describe "with a surviving zframe_t" do
      # this is the case if:
      # * there's an error, or
      # * the REUSE flag was set

      let(:current_delegate) { frame.ffi_delegate }
      let!(:old_delegate) { frame.ffi_delegate }

      describe "with REUSE option set" do
        it "provides correct flags" do
          provided_flags = nil
          expect(CZMQ::FFI::Zframe).to receive(:send) do |zframe,_,flags|
            provided_flags = flags
            zframe.__ptr_give_ref # detach, so it won't try to free()
          end.and_return(0)
          frame.send_to(socket, reuse: true)
          assert_operator CZTop::Frame::FLAG_REUSE & provided_flags, :>, 0
        end
        it "wraps native counterpart in new Zframe" do
          expect(CZMQ::FFI::Zframe).to receive(:send) do |zframe,_,flags|
            zframe.__ptr_give_ref # detach, so it won't try to free()
          end.and_return(0)
          frame.send_to(socket, reuse: true)
          refute_same old_delegate, current_delegate
        end
      end

      describe "when there's an error" do # avoid memory leak
        before(:each) do
          expect(CZMQ::FFI::Zframe).to receive(:send) do |zframe,_,flags|
            zframe.__ptr_give_ref # detach, so it won't try to free()
          end.and_return(-1)
        end
        let(:expected_return_code) { -1 } # fake an error
        it "wraps native counterpart in new Zframe" do
          frame.send_to(socket) rescue nil
          refute_same old_delegate, current_delegate
        end

        it "raises Error" do
          assert_raises(CZTop::Frame::Error) do
            frame.send_to(socket)
          end
        end
      end
    end
  end

  describe ".receive_from"

  describe "#initialize" do
    context "given content" do
      let(:content) { "foobar" }
      let(:frame) { described_class.new content }
      it "initializes frame with content" do
        assert_equal content, frame.content
      end
    end

    context "given no content" do
      let(:frame) { described_class.new }
      it "initializes empty frame" do
        assert_empty frame
      end
      it "has empty string as content" do
        assert_equal "", frame.content
      end
    end
  end

  describe "#size" do
    Given(:content) { "foobar" }
    Given(:frame) { described_class.new(content) }
    Then { content.bytesize == frame.size }
  end

  describe "#empty" do
    context "given empty frame" do
      let(:frame) { described_class.new }
      it "returns true" do
        assert_operator frame, :empty?
      end
    end

    context "given non-empty frame" do
      let(:frame) { described_class.new("foo") }
      it "returns false" do
        refute_operator frame, :empty?
      end
    end
  end

  describe "#content" do
    let(:content) { "foobar" }
    let(:frame) { described_class.new(content) }
    it "returns its content as a String" do
      assert_equal content, frame.content
    end

    it "has alias #to_s" do
      assert_equal content, frame.to_s
    end

    it "returns content as binary string" do
      assert_equal Encoding::BINARY, frame.to_s.encoding
    end
  end

  describe "#content=" do
    Given(:frame) { described_class.new }
    When { frame.content = content }
    context "with text content" do
      Given(:content) { "foobar" }
      # doesn't include trailing null byte
      Then { content == frame.content }
      And { content.bytesize == frame.size }
    end

    context "with binary content" do
      Given(:content) { "foobar".encode!(Encoding::BINARY) }
      Then { content == frame.content }
      Then { content.bytesize == frame.size }
    end
  end

  describe "#dup" do
    context "given frame and its duplicate" do
      Given(:frame) { described_class.new("foo") }
      When(:duplicate_frame) { frame.dup }
      Then { frame == duplicate_frame } # equal frame
      And { frame.content == duplicate_frame.content } # same content
      And { not frame.equal?(duplicate_frame) } # not same object
    end
  end

  describe "#more?" do
    Given(:frame) { described_class.new }
    context "given Frame with MORE indicator set" do
      When { frame.more = true }
      Then { frame.more? }
    end
    context "given Frame with MORE indicator NOT set" do
      When { frame.more = false }
      Then { not frame.more? }
    end
  end

  describe "#more=" do
    Given(:frame) { described_class.new }
    Then { not frame.more? }

    context "when setting to true" do
      When { frame.more = true }
      Then { frame.more? }
    end

    context "when setting to false" do
      When { frame.more = false }
      Then { not frame.more? }
    end
  end

  describe "#==" do
    let(:frame) { described_class.new("foo") }
    context "given identical other frame" do
      let(:other_frame) { described_class.new("foo") }
      it "is equal" do
        assert_operator frame, :==, other_frame
        assert_operator other_frame, :==, frame
      end

      context "given other frame has MORE flag set" do
        let(:other_frame) { f=described_class.new("foo"); f.more=true; f }
        it "is still equal" do
          assert_operator frame, :==, other_frame
        end
      end
    end

    context "given different other frame" do
      let(:other_frame) { described_class.new("bar") }
      it "is not equal" do
        refute_operator frame, :==, other_frame
        refute_operator other_frame, :==, frame
      end
    end
  end

  describe "#routing_id" do
    Given(:frame) { described_class.new }
    context "with no routing ID set" do
      Then { frame.routing_id == 0 }
    end

    context "with routing ID set" do
      Given(:new_routing_id) { 123456 }
      When { frame.routing_id = new_routing_id }
      Then { frame.routing_id == new_routing_id }
    end
  end

  describe "#routing_id=" do
    Given(:frame) { described_class.new }

    context "with valid routing ID" do
      # code duplication for completeness' sake
      Given(:new_routing_id) { 123456 }
      When { frame.routing_id = new_routing_id }
      Then { frame.routing_id == new_routing_id }
    end

    context "with negative routing ID" do
      Given(:new_routing_id) { -123456 }
      When(:result) { frame.routing_id = new_routing_id }
      Then { result == Failure(RangeError) }
    end

    context "with too big routing ID" do
      Given(:new_routing_id) { 123456345676543456765 }
      When(:result) { frame.routing_id = new_routing_id }
      Then { result == Failure(RangeError) }
    end
  end
end
