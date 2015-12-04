require_relative '../spec_helper'

describe CZTop::Message do
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
      let(:frame) { CZTop::Frame.new() }
      it "creates a new Message from the Frame"
    end
  end

  describe "" do
  end
end
