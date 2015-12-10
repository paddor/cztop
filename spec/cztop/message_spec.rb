require_relative 'spec_helper'

describe CZTop::Message do
  include_examples "has FFI delegate"

  context "new Message" do
    subject { CZTop::Message.new }
    it "is empty" do
      assert_empty subject
    end
    it "has content size zero" do
      assert_equal 0, subject.content_size
    end
    it "has no frames" do
      assert_equal 0, subject.size
    end

    context "with initial string" do
      let(:content) { "foo" }
      subject { described_class.new(content) }
      it "gets that string" do
        assert_equal content, subject.frames.first.to_s
      end

      it "has non-zero content size" do
        assert_operator subject.content_size, :>, 0
      end

      it "has one frame" do
        assert_equal 1, subject.frames.count
      end
    end

    context "with multiple parts" do
      Given(:parts) { [ "foo", "", "bar"] }
      When(:msg) { described_class.new(parts) }
      Then { msg.size == parts.size }
    end
  end

  describe ".coerce" do
    context "given a Message" do
      let(:msg) { described_class.new }
      it "takes the Message as is" do
        assert_same msg, described_class.coerce(msg)
      end
    end

    context "given a String" do
      let(:content) { "foobar" }
      let(:coerced_msg) { described_class.coerce(content) }
      it "creates a new Message from the String" do
        assert_kind_of described_class, coerced_msg
        assert_equal 1, coerced_msg.size
        assert_equal content, coerced_msg.frames.first.to_s
      end
    end

    context "given a Frame" do
      Given(:frame_content) { "foobar special content" }
      Given(:frame) { CZTop::Frame.new(frame_content) }
      When(:coerced_msg) { described_class.coerce(frame) }
      Then { coerced_msg.kind_of? described_class }
      And { coerced_msg.size == 1 }
      And { coerced_msg.frames.first.to_s == frame_content }
    end
  end

  describe "#routing_id" do
    Given(:msg) { described_class.new }
    context "with no routing ID set" do
      Then { msg.routing_id == 0 }
    end
    context "with routing ID set" do
      Given(:routing_id) { 12345 }
      When { msg.routing_id = routing_id }
      Then { msg.routing_id == routing_id }
    end
  end

  describe "#routing_id=" do
    Given(:msg) { described_class.new }

    context "with valid routing ID" do
      # code duplication for completeness' sake
      Given(:new_routing_id) { 123456 }
      When { msg.routing_id = new_routing_id }
      Then { msg.routing_id == new_routing_id }
    end

    context "with negative routing ID" do
      Given(:new_routing_id) { -123456 }
      When(:result) { msg.routing_id = new_routing_id }
      Then { result == Failure(RangeError) }
    end

    context "with too big routing ID" do
      Given(:new_routing_id) { 123456345676543456765 }
      When(:result) { msg.routing_id = new_routing_id }
      Then { result == Failure(RangeError) }
    end
  end
end
