require_relative 'spec_helper'

describe CZTop::Frame do

  describe "#initialize" do
    context "content given" do
      let(:content) { "foobar" }
      let(:frame) { described_class.new content }
      it "initializes frame with content" do
        assert_equal content, frame.content
      end
    end

    context "no content given" do
      let(:frame) { described_class.new }
      it "initializes empty frame" do
        assert_empty frame
      end
    end
  end

  describe "#size" do
    it "returns its size"
  end

  describe "#to_s" do
    it "returns its content as a String"
  end

  describe "#content" do
    it "returns content"
  end

  describe "#content=" do
    context "given text content" do
      it "sets content"
      it "doesn't include trailing null byte"
    end

    context "given binary content" do
      it "sets content"
      it "includes all bytes"
    end
  end
end
