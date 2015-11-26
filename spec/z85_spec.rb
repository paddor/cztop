require_relative 'spec_helper'

describe CZTop::Z85 do
  # "even" means its length is divisible by 4
  let(:even_string) { "foo bar bazz" } # 12 bytes
  let(:odd_string) { "foo bar baz" } # 11 bytes
  let(:binary_data) do
    "\0\x13\x24\x10\x12\x13\x14\x00\x00".
      force_encoding(Encoding::ASCII_8BIT)
  end
  subject { CZTop::Z85.new }

  it "instantiates" do
    assert_kind_of CZTop::Z85, subject
  end

  it "uses Z85" do
    assert_equal "z85", subject.mode
  end

  it "encodes an odd string" do
    z85_string = subject.encode(odd_string)
    assert_equal "w]zPgvQTp1vQTM.", z85_string
  end

  it "round trips with even string" do
    z85_string = subject.encode(even_string)
    assert_equal even_string, subject.decode(z85_string)
  end

  it "encodes an empty string" do
    assert_equal "", subject.encode("")
  end

  describe "#decode" do
    it "decodes an empty string" do
      assert_equal "", subject.decode("")
    end

    context "input of wrong size" do
      let(:wrong_z85) { "w]zPgvQTp1vQTO" } # 14 instead of 15 chars
      it "raises" do
        assert_raises(ArgumentError) { subject.decode(wrong_z85) }
      end
    end
  end


#  it "decodes as binary data" do
#    z85_string = subject.encode(even_string)
#    decoded = subject.decode(z85_string)
#    assert_equal Encoding::ASCII_8BIT, decoded.encoding
#  end

#  it "round trips with binary data" do
#    z85_string = subject.encode(binary_data)
#    assert_equal binary_data, subject.decode(z85_string)
#  end

  it "decodes back to the string"

  it "decodes back to the binary string"

end
