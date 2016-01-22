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

describe CZTop::Socket::CLIENT, skip: czmq_function?(:zsock_new_client) do
  Given(:socket) { described_class.new }
  it "instanciates" do
    socket
  end
end

describe CZTop::Socket::SERVER, skip: czmq_function?(:zsock_new_server) do

  Given(:server) { CZTop::Socket::SERVER.new }
  it "instanciates" do
    server
  end

  describe "when communicating" do
    i = 58578
    Given(:endpoint) { "inproc://server_spec_#{i += 1}" }
    Given(:server) do
      s = CZTop::Socket::SERVER.new(endpoint)
      s.options.sndtimeo = 50
      s
    end
    Given(:client) do
      s = CZTop::Socket::CLIENT.new(endpoint)
      s.options.sndtimeo = 50
      s
    end
    Given(:msg_content) { "FOO" }
    Given(:routing_id) { 23456 }

    Given(:msg) { CZTop::Message.new(msg_content) }
    Given(:received_msg) { server.receive }

    context "when receiving message from CLIENT" do
      When { client << msg_content }
      Then { received_msg[0].to_s == msg_content }
      And { received_msg.routing_id > 0 }
    end

    context "when responding to a message from CLIENT" do
      Given { client << msg_content }
      Given { received_msg }
      Given(:response) { CZTop::Message.new("BAR") }
      context "with routing_id set" do
        Given { response.routing_id = received_msg.routing_id }
        When { server << response }
        Then { client.receive[0] == "BAR" }
      end
      context "with two responses with routing_id set" do
        Given(:second_response) { CZTop::Message.new("BAZ") }
        Given { response.routing_id = received_msg.routing_id }
        Given { second_response.routing_id = received_msg.routing_id }
        When { server << response << second_response }
        Then { client.receive[0] == "BAR" && client.receive[0] == "BAZ" }
      end
      context "with wrong routing_id set" do
        Given { response.routing_id = 1234 } # wrong routing_id
        When(:result) { server << response }
        Then { result == Failure(SocketError) }
      end
      context "without routing_id set" do
        When(:result) { server << response }
        Then { result == Failure(SocketError) }
      end
      context "with disconnected CLIENT" do
        Given { client.disconnect(endpoint) }
        Given { response.routing_id = received_msg.routing_id }
        When(:result) { server << response }
        Then { result == Failure(IO::EAGAINWaitWritable) }
      end
      describe "with multi-part response" do
        Given(:response) { CZTop::Message.new(%w[BAR BAZ]) }
        Given { response.routing_id = received_msg.routing_id }
        When(:result) { server << response }
        Then { result == Failure(ArgumentError) }
      end
    end

    describe "when SERVER tries to initiate a conversation" do
      Given { client }
      Given { server }
      Given { msg.routing_id = 1234 } # fake routing_id
      When(:result) { server << msg }
      Then { result == Failure(SocketError) }
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
  let(:endpoint) { "inproc://socket_types_spec_#{i+=1}" }
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
