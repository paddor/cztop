require_relative 'spec_helper'

describe CZTop::Frame do

  describe ".send_to"
  describe ".receive_from"

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

  describe "#empty" do
    context "given empty frame" do
      it "returns true"
    end

    context "given non-empty frame" do
      it "returns false"
    end
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

  describe "#dup" do
    it "duplicates a frame"
  end

  describe "#more?" do
    it "tells if MORE indicator is set"
  end

  describe "#more=" do
    it "sets the MORE indicator"
  end

  describe "#==" do
    context "identical other frame" do
      it "returns true"
    end
    context "different other frame" do
      it "returns false"
    end
  end
end
