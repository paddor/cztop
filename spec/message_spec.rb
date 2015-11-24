require_relative 'spec_helper'

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
      it "takes the Message as is"
    end

    context "given a String" do
      it "creates a new Message from the String"
    end

    context "given a Frame" do
      it "creates a new Message from the Frame"
    end
  end

  describe "" do
  end
end
