require_relative '../../spec_helper'

describe CZTop::Z85::Padded do
  subject { CZTop::Z85::Padded.new }

  describe "#encode" do
    let(:encoded) { subject.encode(input) }
    let(:output_size) { encoded.bytesize }

    context "with empty data" do
      let(:input) { "" }
      it "returns empty string" do
        assert_equal "", encoded
      end
    end

    context "with even data" do
      let(:input) { "abcd" }

      it "encodes to correct size" do
        assert_equal 10, output_size
      end
    end

    context "with uneven data" do
      let(:input) { "abc" }

      it "encodes to correct size" do
        assert_equal 5, output_size
      end
    end
  end

  describe "#decode" do
    context "with empty data" do
      it "decodes without trying chop off padding" do
        assert_equal "", subject.decode("")
      end
    end
  end

  it "round trips" do
    input = "foo bar baz"
    z85 = subject.encode(input)
    assert_equal input, subject.decode(z85)
  end

  describe ".encode" do
    let(:input) { "abcde" * 1_000 }
    it "does the same as #encode" do
      assert_equal CZTop::Z85::Padded.new.encode(input),
        CZTop::Z85::Padded.encode(input)
    end
  end
  describe ".decode" do
    let(:input) { CZTop::Z85::Padded.new.encode("abcde" * 1_000) }
    it "does the same as #decode" do
      assert_equal CZTop::Z85::Padded.new.decode(input),
        CZTop::Z85::Padded.decode(input)
    end
  end
end
