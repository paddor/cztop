require_relative 'spec_helper'

describe CZTop::Z85 do
  include_examples "has FFI delegate"
  subject { CZTop::Z85.new }

  it "instantiates" do
    assert_kind_of CZTop::Z85, subject
  end

  describe "#encode" do
    context "empty data" do
      it "encodes" do
        assert_equal "", subject.encode("")
      end
      it "returns ASCII encoded string" do
        assert_equal Encoding::ASCII, subject.encode("").encoding
      end
    end

    context "even data" do
      # "even" means its length is divisible by 4 with no remainder

      # test data from https://github.com/zeromq/rfc/blob/master/src/spec_32.c
      let(:input) do
        [
          0x8E, 0x0B, 0xDD, 0x69, 0x76, 0x28, 0xB9, 0x1D, 
          0x8F, 0x24, 0x55, 0x87, 0xEE, 0x95, 0xC5, 0xB0, 
          0x4D, 0x48, 0x96, 0x3F, 0x79, 0x25, 0x98, 0x77, 
          0xB4, 0x9C, 0xD9, 0x06, 0x3A, 0xEA, 0xD3, 0xB7  
        ].map { |i| i.chr }.join
      end
      let(:expected_output) { "JTKVSB%%)wK0E.X)V>+}o?pNmC{O&4W4b!Ni{Lh6" }

      it "encodes test data" do
        assert_equal expected_output, subject.encode(input)
      end

      it "round trips" do
        z85 = subject.encode(input)
        assert_equal input, subject.decode(z85)
      end
    end

    context "odd data" do
      # input length is not divisible by 4 with no remainder
      let(:data) { "foo bar" } # 7 bytes

      it "raises" do
        assert_raises(ArgumentError) { subject.encode(data) }
      end
    end
  end

  describe "#decode" do
    context "empty data" do
      it "decodes" do
        assert_equal "", subject.decode("")
      end
    end

    context "even data" do
      let(:input) { "HelloWorld" }
      let(:expected_output) do
        "\x86\x4F\xD2\x6F\xB5\x59\xF7\x5B".force_encoding Encoding::BINARY
      end

      it "decodes" do
        assert_equal expected_output, subject.decode(input)
      end

      it "returns binary encoded string" do
        assert_equal Encoding::BINARY, subject.decode(input).encoding
      end
    end

    context "odd data" do
      let(:data) { "w]zPgvQTp1vQTO" } # 14 instead of 15 chars
      it "raises" do
        assert_raises(ArgumentError) { subject.decode(data) }
      end
    end
  end
end
