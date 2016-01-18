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
    let(:socket) { described_class.new_by_type(type) }
    context "given valid type" do
      let(:expected_class) { CZTop::Socket::PUSH }
      context "by integer" do
        let(:type) { CZTop::Socket::Types::PUSH }
        it "returns socket" do
          assert_kind_of Integer, type
          assert_kind_of expected_class, socket
        end
      end
      context "by symbol" do
        let(:type) { :PUSH }
        it "returns socket" do
          assert_kind_of expected_class, socket
        end
      end
    end

    context "given invalid type name" do
      context "by integer" do
        let(:type) { 99 } # non-existent type
        it "raises" do
          assert_raises(ArgumentError) { socket }
        end
      end
      context "by symbol" do
        let(:type) { :FOOBAR } # non-existent type
        it "raises" do
          assert_raises(NameError) { socket }
        end
      end
      context "by string" do
        # NOTE: No support for Strings as socket types for now.
        let(:type) { "PUB" }
        it "raises" do
          assert_raises(ArgumentError) { socket }
        end
      end
      context "by Socket::* class" do
        # NOTE: No support for socket Socket::* classes as types for now.
        let(:type) { CZTop::Socket::PUB }
        it "raises" do
          assert_raises(ArgumentError) { socket }
        end
      end
    end
  end
end

describe CZTop::Socket::CLIENT do
  Given(:socket) { described_class.new }
  it "instanciates" do
    socket
  end
end

describe CZTop::Socket::SERVER do
  Given(:socket) { described_class.new }

  it "instanciates" do
    socket
  end

  describe "#routing_id" do
    context "with no routing ID set" do
      Then { socket.routing_id == 0 }
    end

    context "with routing ID set" do
      Given(:new_routing_id) { 123456 }
      When { socket.routing_id = new_routing_id }
      Then { socket.routing_id == new_routing_id }
    end
  end

  describe "#routing_id=" do
    context "with valid routing ID" do
      # code duplication for completeness' sake
      Given(:new_routing_id) { 123456 }
      When { socket.routing_id = new_routing_id }
      Then { socket.routing_id == new_routing_id }
    end

    context "with negative routing ID" do
      Given(:new_routing_id) { -123456 }
      When(:result) { socket.routing_id = new_routing_id }
      Then { result == Failure(RangeError) }
    end

    context "with too big routing ID" do
      Given(:new_routing_id) { 123456345676543456765 }
      When(:result) { socket.routing_id = new_routing_id }
      Then { result == Failure(RangeError) }
    end
  end
end

describe CZTop::Socket::REQ do
  Given(:socket) { described_class.new }
  Then { socket }
end

describe CZTop::Socket::REP do
  Given(:socket) { described_class.new }
  Then { socket }
end

describe CZTop::Socket::DEALER do
  Given(:socket) { described_class.new }
  Then { socket }
end

describe CZTop::Socket::ROUTER do
  Given(:socket) { described_class.new }
  Then { socket }

  describe "#send_to" do
    let(:receiver) { "mike" }
    let(:content) { "foobar" }
    it "sends message to receiver" do
      expect(socket).to receive(:<<) do |msg|
        assert_equal [receiver, "", content], msg.to_a
      end
      socket.send_to(receiver, content)
    end
  end
end

describe CZTop::Socket::PUB do
  Given(:socket) { described_class.new }
  Then { socket }
end

describe CZTop::Socket::SUB do
  Given(:socket) { described_class.new }
  Then { socket }

  let(:subscription) { "test_prefix" }

  context "with subscription" do
    it "subscribes" do
      expect(::CZMQ::FFI::Zsock).to receive(:new_sub).with(nil, subscription).
        and_call_original

      described_class.new(nil, subscription)
    end
  end

  describe "#subscribe" do
    it "subscribes" do
      expect(socket.ffi_delegate).to receive(:set_subscribe).with(subscription)
      socket.subscribe(subscription)
    end
  end
  describe "#unsubscribe" do
    it "unsubscribes" do
      expect(socket.ffi_delegate).to receive(:set_unsubscribe).with(subscription)
      socket.unsubscribe(subscription)
    end
  end
end

describe CZTop::Socket::XPUB do
  Given(:socket) { described_class.new }
  Then { socket }
end

describe CZTop::Socket::XSUB do
  Given(:socket) { described_class.new }
  Then { socket }
end

describe CZTop::Socket::PUSH do
  Given(:socket) { described_class.new }
  Then { socket }
end

describe CZTop::Socket::PULL do
  Given(:socket) { described_class.new }
  Then { socket }
end

describe CZTop::Socket::PAIR do
  i = 0
  let(:endpoint) { "inproc://endpoint_socket_types_spec_#{i+=1}" }
  let(:binding_socket) { described_class.new("@#{endpoint}") }
  let(:connecting_socket) { described_class.new(">#{endpoint}") }

  it "creates PAIR sockets" do
    binding_socket
    connecting_socket
  end

  it "raises when more than 2 PAIR sockets are connected" do
    binding_socket
    connecting_socket
    assert_raises(SystemCallError) do
      described_class.new("@#{endpoint}")
    end
    assert_raises do
      CZMQ::Socket::PAIR.new(">#{endpoint}")
    end
  end
end

describe CZTop::Socket::STREAM do
  Given(:socket) { described_class.new }
  Then { socket }
end
