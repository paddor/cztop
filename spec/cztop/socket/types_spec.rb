require_relative '../../spec_helper'

describe CZTop::Socket::Types do
  it "has constants" do
    assert_equal 14, described_class.constants.size
  end

  it "has names for each type" do
    assert_equal CZTop::Socket::Types.constants.sort,
      CZTop::Socket::TypeNames.values.sort
  end

  it "has an entry for each socket type" do
    CZTop::Socket::Types.constants.each do |const_name|
      type_code = CZTop::Socket::Types.const_get(const_name)
      assert_operator CZTop::Socket::TypeNames, :has_key?, type_code
      assert_equal const_name, CZTop::Socket::TypeNames[type_code]
    end
  end
end

describe CZTop::Socket do
  describe ".new_by_type" do
    context "given valid type" do
      let(:expected_class) { CZTop::Socket::PUSH }
      context "by integer" do
        let(:type) { CZTop::Socket::Types::PUSH }
        it "returns socket" do
          assert_kind_of Integer, type
          assert_kind_of expected_class, described_class.new_by_type(type)
        end
      end
      context "by symbol" do
        let(:type) { :PUSH }
        it "returns socket" do
          assert_kind_of expected_class, described_class.new_by_type(type)
        end
      end
    end

    context "given invalid type name" do
      context "by integer" do
        let(:type) { 99 } # non-existent type
        it "raises" do
          assert_raises(ArgumentError) { described_class.new_by_type(type) }
        end
      end
      context "by symbol" do
        let(:type) { :FOOBAR } # non-existent type
        it "raises" do
          assert_raises(NameError) { described_class.new_by_type(type) }
        end
      end
      context "by other kind" do
        # NOTE: No support for socket types as Strings for now.
        let(:type) { "PUB" }
        it "raises" do
          assert_raises(ArgumentError) { described_class.new_by_type(type) }
        end
      end
    end
  end
end

describe CZTop::Socket::CLIENT do
  # TODO

  # * endpoints can be nil
  # * if not nil, expect call to Zsock.new_client
end

describe CZTop::Socket::SERVER do
  # TODO
end

describe CZTop::Socket::REQ do
  # TODO
end

describe CZTop::Socket::REP do
  # TODO
end

describe CZTop::Socket::DEALER do
  # TODO
end

describe CZTop::Socket::ROUTER do
  # TODO
end

describe CZTop::Socket::PUB do
  # TODO
end

describe CZTop::Socket::SUB do
  # TODO
end

describe CZTop::Socket::XPUB do
  # TODO
end

describe CZTop::Socket::XSUB do
  # TODO
end

describe CZTop::Socket::PUSH do
  # TODO
end

describe CZTop::Socket::PULL do
  # TODO
end

describe CZTop::Socket::PAIR do
  # TODO
end

describe CZTop::Socket::STREAM do
  # TODO
end
