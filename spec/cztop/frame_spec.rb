require_relative '../spec_helper'

describe CZTop::Frame do

  describe ".send_to"
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

  describe "#routing_id=" do
    Given(:frame) { described_class.new }
    context "setting routing"
  end
end
