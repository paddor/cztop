# frozen_string_literal: true

require_relative '../../spec_helper'

describe CZTop::Socket::Types do
  it 'has constants' do
    CZTop::Socket::Types::PAIR
    CZTop::Socket::Types::PUB
    CZTop::Socket::Types::SUB
    CZTop::Socket::Types::REQ
    CZTop::Socket::Types::REP
    CZTop::Socket::Types::DEALER
    CZTop::Socket::Types::ROUTER
    CZTop::Socket::Types::PULL
    CZTop::Socket::Types::PUSH
    CZTop::Socket::Types::XPUB
    CZTop::Socket::Types::XSUB
    CZTop::Socket::Types::STREAM
    CZTop::Socket::Types::SERVER
    CZTop::Socket::Types::CLIENT
    CZTop::Socket::Types::RADIO
    CZTop::Socket::Types::DISH
    CZTop::Socket::Types::GATHER
    CZTop::Socket::Types::SCATTER
  end

  it 'has names for each type' do
    assert_equal CZTop::Socket::Types.constants.sort,
                 CZTop::Socket::TypeNames.values.sort
  end

  it 'has an entry for each socket type' do
    CZTop::Socket::Types.constants.each do |const_name|
      type_code = CZTop::Socket::Types.const_get(const_name)
      assert_operator CZTop::Socket::TypeNames, :has_key?, type_code
      assert_equal const_name, CZTop::Socket::TypeNames[type_code]
    end
  end
end

describe CZTop::Socket do
  describe '.new_by_type' do
    let(:socket) { described_class.new_by_type(type) }
    context 'given valid type' do
      let(:expected_class) { CZTop::Socket::PUSH }
      context 'by integer' do
        let(:type) { CZTop::Socket::Types::PUSH }
        it 'returns socket' do
          assert_kind_of Integer, type
          assert_kind_of expected_class, socket
        end
      end
      context 'by symbol' do
        let(:type) { :PUSH }
        it 'returns socket' do
          assert_kind_of expected_class, socket
        end
      end
    end

    context 'given invalid type name' do
      context 'by integer' do
        let(:type) { 99 } # non-existent type
        it 'raises' do
          assert_raises(ArgumentError) { socket }
        end
      end
      context 'by symbol' do
        let(:type) { :FOOBAR } # non-existent type
        it 'raises' do
          assert_raises(NameError) { socket }
        end
      end
      context 'by string' do
        # NOTE: No support for Strings as socket types for now.
        let(:type) { 'PUB' }
        it 'raises' do
          assert_raises(ArgumentError) { socket }
        end
      end
      context 'by Socket::* class' do
        # NOTE: No support for socket Socket::* classes as types for now.
        let(:type) { CZTop::Socket::PUB }
        it 'raises' do
          assert_raises(ArgumentError) { socket }
        end
      end
    end
  end
end

describe CZTop::Socket::CLIENT, if: has_czmq_drafts? do
  Given(:client) do
    described_class.new.tap do |client|
      client.connect endpoint
    end
  end

  Given(:server) do
    CZTop::Socket::SERVER.new.tap do |server|
      server.bind endpoint
    end
  end
  i = 54_578
  Given(:endpoint) { "inproc://client_spec_#{i += 1}" }

  it 'instanciates' do
    client
  end

  context 'while connected' do
    before do
      server
      client
      sleep 0.1
    end

    it 'can exchange message' do
      client << 'foo'
      request = server.receive
      assert_equal ['foo'], request.to_a
      response = CZTop::Message.new('bar').tap { |msg| msg.routing_id = request.routing_id }
      server << response
      assert_equal ['bar'], client.receive.to_a
    end

    context 'when sending multi-part message' do
      it 'raises' do
        assert_raises(ArgumentError) do
          client << %w[foo bar]
        end
      end
    end
  end
end

describe CZTop::Socket::SERVER, if: has_czmq_drafts? do
  Given(:server) { CZTop::Socket::SERVER.new }
  it 'instanciates' do
    server
  end

  describe '#to_io' do
    Given { server }
    Then do
      assert_kind_of IO, server.to_io
    end
  end

  describe 'when communicating' do
    i = 58_578
    Given(:endpoint) { "inproc://server_spec_#{i += 1}" }
    Given(:server_sndtimeo) { 50 }
    Given(:server) do
      CZTop::Socket::SERVER.new.tap do |s|
        s.options.sndtimeo = server_sndtimeo
        s.bind(endpoint)
      end
    end
    Given(:client_sndtimeo) { 50 }
    Given(:client) do
      CZTop::Socket::CLIENT.new.tap do |s|
        s.options.sndtimeo = 50
        s.connect(endpoint)
      end
    end
    Given(:msg_content) { 'FOO' }
    Given(:routing_id) { 23_456 }

    Given(:msg) { CZTop::Message.new(msg_content) }
    Given(:received_msg) { server.receive }

    context 'when receiving message from CLIENT' do
      When { client << msg_content }
      Then { received_msg[0].to_s == msg_content }
      And { received_msg.routing_id > 0 }
    end

    context 'when responding to a message from CLIENT' do
      Given { client << msg_content }
      Given { received_msg }
      Given(:response) { CZTop::Message.new('BAR') }
      context 'with routing_id set' do
        Given { response.routing_id = received_msg.routing_id }
        When { server << response }
        Then { client.receive[0] == 'BAR' }
      end
      context 'with two responses with routing_id set' do
        Given(:second_response) { CZTop::Message.new('BAZ') }
        Given { response.routing_id = received_msg.routing_id }
        Given { second_response.routing_id = received_msg.routing_id }
        When { server << response << second_response }
        Then { client.receive[0] == 'BAR' && client.receive[0] == 'BAZ' }
      end
      context 'with wrong routing_id set' do
        context 'with SERVER SNDTIMEO set' do
          Given(:server_timeo) { 50 }
          Given { response.routing_id = 1234 } # wrong routing_id
          When(:result) { server << response }
          Then { result == Failure(SocketError) }
        end
        context 'with no SERVER SNDTIMEO set' do
          Given(:server_timeo) { 0 }
          Given { response.routing_id = 1234 } # wrong routing_id
          When(:result) { server << response }
          Then { result == Failure(SocketError) }
        end
      end
      context 'without routing_id set' do
        When(:result) { server << response }
        Then { result == Failure(SocketError) }
      end
      context 'with disconnected CLIENT' do
        Given { client.disconnect(endpoint) }
        Given { response.routing_id = received_msg.routing_id }
        When(:result) { server << response }
        Then { result == Failure(IO::EAGAINWaitWritable) }
      end
      describe 'with multi-part response' do
        Given(:response) { CZTop::Message.new(%w[BAR BAZ]) }
        Given { response.routing_id = received_msg.routing_id }
        When(:result) { server << response }
        Then { result == Failure(ArgumentError) }
      end
    end

    describe 'when SERVER tries to initiate a conversation' do
      Given { client }
      Given { server }
      Given { msg.routing_id = 1234 } # fake routing_id
      When(:result) { server << msg }
      Then { result == Failure(SocketError) }
    end
  end
end

describe CZTop::Socket::RADIO, if: has_czmq_drafts? do
  Given(:socket) { described_class.new }
  Then { socket }

  describe '#to_io' do
    Given { socket }
    Then do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::DISH, if: has_czmq_drafts? do
  i = 0
  Given(:endpoint) { "inproc://radio-dish_spec_#{i += 1}" }
  Given(:timeout) { 20 }
  Given(:radio) do
    CZTop::Socket::RADIO.new.tap do |s|
      s.options.sndtimeo = timeout
      s.bind(endpoint)
    end
  end
  Given(:dish) do
    described_class.new.tap do |s|
      s.options.rcvtimeo = timeout
      s.connect(endpoint)
    end
  end
  Given(:group) { 'group1' }

  describe '#to_io' do
    Given { dish }
    Then do
      assert_kind_of IO, dish.to_io
    end
  end

  describe '#join' do
    context 'given a message sent to a joined group' do
      Given { dish.join group }
      Given(:msg) { CZTop::Frame.new('foo').tap { |f| f.group = group } }
      When { radio << msg }
      When(:received) { dish.receive }
      Then { group == received.frames[0].group }
      And { 'foo' == received[0] }
    end

    context 'given a message sent to an unjoined group' do
      Given { dish.join group }
      Given(:msg) { CZTop::Frame.new('foo').tap { |f| f.group = 'group2' } }
      When { radio << msg }
      When(:result) { dish.receive }
      Then { result == Failure(IO::TimeoutError) }
    end

    context 'given an invalid group name' do
      Given(:group) { 'x' * 256 }
      When(:result) { dish.join group }
      Then { result == Failure(ArgumentError) }
    end

    context 'given an already joined group' do
      Given(:group) { 'group1' }
      When { dish.join group }
      When(:result) { dish.join group }
      Then { result == Failure(ArgumentError) }
    end
  end
  describe '#leave' do
    context 'leaving a previously joined group' do
      Given(:group) { 'group1' }
      When { dish.join group }
      When(:result) { dish.leave group }
      Then { true }
    end
    context 'leaving an unjoined group' do
      Given(:unjoined_group) { 'group1' }
      When(:result) { dish.leave unjoined_group }
      Then { result == Failure(ArgumentError) }
    end
  end
end

describe CZTop::Socket::SCATTER, if: has_czmq_drafts? do
  Given(:socket) { described_class.new }
  Then { socket }
end

describe CZTop::Socket::GATHER, if: has_czmq_drafts? do
  i = 0
  Given(:endpoint) { "inproc://scatter-gather_spec_#{i += 1}" }
  Given(:timeout) { 20 }
  Given(:scatter) do
    CZTop::Socket::SCATTER.new.tap do |s|
      s.options.sndtimeo = timeout
      s.bind(endpoint)
    end
  end
  Given(:gather) do
    described_class.new.tap do |s|
      s.options.rcvtimeo = timeout
      s.connect(endpoint)
    end
  end

  context 'given message from SCATTER' do
    Given { gather }
    Given { scatter << 'foo' }
    When(:msg) { gather.receive }
    Then { 'foo' == msg.to_a[0] }
  end

  context 'given message from SCATTER and multiple GATHER sockets' do
    Given { gather }
    Given(:gather2) do
      described_class.new.tap do |s|
        s.options.rcvtimeo = timeout
        s.connect(endpoint)
      end
    end
    Given { scatter << 'foo' }
    When(:result1) { gather.receive }
    When(:result2) { gather2.receive }
    Then { result1 == Failure(IO::TimeoutError) || result2 == Failure(IO::TimeoutError) }
    And { result1.is_a?(CZTop::Message) || result2.is_a?(CZTop::Message) }
  end
end

describe CZTop::Socket::REQ do
  Given(:socket) { described_class.new }
  Then { socket }

  describe '#to_io' do
    Given { socket }
    Then do
      assert_kind_of IO, socket.to_io
    end
  end

  context 'integration' do
    let(:req) { CZTop::Socket::REQ.new }
    let(:rep) { CZTop::Socket::REP.new }
    i = 0
    let(:endpoint) { "inproc://socket_types_spec_reqrep_#{i += 1}" }

    before do
      req.options.sndtimeo = 100
      rep.options.rcvtimeo = 100

      req.bind endpoint
      rep.connect endpoint
    end

    it 'can send message' do
      req << 'foobar'
      msg = rep.receive
      assert_equal ['foobar'], msg.to_a

      rep << 'baz'
      msg = req.receive
      assert_equal ['baz'], msg.to_a

      req << %w[foobar]
      msg = rep.receive
      assert_equal %w[foobar], msg.to_a

      rep << %w[bazzz]
      msg = req.receive
      assert_equal %w[bazzz], msg.to_a
    end
  end
end

describe CZTop::Socket::REP do
  Given(:socket) { described_class.new }
  Then { socket }

  describe '#to_io' do
    Given { socket }
    Then do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::DEALER do
  Given(:socket) { described_class.new }
  Then { socket }

  describe '#to_io' do
    Given { socket }
    Then do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::ROUTER do
  Given(:socket) { described_class.new }
  Then { socket }

  describe '#to_io' do
    Given { socket }
    Then do
      assert_kind_of IO, socket.to_io
    end
  end

  describe '#send_to' do
    let(:receiver) { 'mike' }
    let(:content) { 'foobar' }
    it 'sends message to receiver' do
      expect(socket).to receive(:<<) do |msg|
        assert_equal [receiver, '', content], msg.to_a
      end
      socket.send_to(receiver, content)
    end
  end


  context 'with ZMQ_ROUTER_MANDATORY flag set' do
    before do
      socket.options.router_mandatory = true
    end

    context 'when connected' do
      let(:identity) { 'receiver identity' }
      let(:content)  { 'foobar' }
      let(:msg)      { [identity, '', content] }


      i = 34_590
      let(:endpoint) { "inproc://router_mandatory_spec_#{i += 1}" }

      let(:dealer) do
        CZTop::Socket::DEALER.new.tap do |dealer|
          dealer.options.identity = identity
          dealer.connect endpoint
        end
      end

      before do
        socket.bind endpoint
        dealer.connect endpoint
        sleep 0.1

        assert_operator socket, :writable?
      end

      context 'for unroutable message' do
        let(:msg_with_wrong_identity) { ['wrong_id', '', content] }

        it 'raises' do
          assert_raises(SocketError) { socket << msg_with_wrong_identity }
        end
      end

      context 'for routable message' do
        let(:identity) { 'receiver identity' }
        let(:content)  { 'foobar' }
        let(:msg)      { [identity, '', content] }

        it 'accepts message' do
          socket << msg
        end

        it 'and delivers it' do
          socket << msg
          msg = dealer.receive
          assert_equal ['', content], msg.to_a
        end
      end
    end
  end
end

describe CZTop::Socket::PUB do
  Given(:socket) { described_class.new }
  Then { socket }

  describe '#to_io' do
    Given { socket }
    Then do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::SUB do
  Given(:socket) { described_class.new }
  Then { socket }

  describe '#to_io' do
    Given { socket }
    Then do
      assert_kind_of IO, socket.to_io
    end
  end

  let(:subscription) { 'test_prefix' }

  context 'with subscription' do
    it 'subscribes' do
      expect(::CZMQ::FFI::Zsock).to receive(:new_sub).with(nil, subscription)
                                                     .and_call_original

      described_class.new(nil, subscription)
    end
  end

  describe '#subscribe' do
    context 'with subscription prefix' do
      before do
        expect(socket.ffi_delegate).to receive(:set_subscribe)
          .with(subscription)
      end
      it 'subscribes' do
        socket.subscribe(subscription)
      end
    end
    context 'without subscription prefix' do
      before do
        expect(socket.ffi_delegate).to receive(:set_subscribe).with('')
      end
      it 'subscribes to everything' do
        socket.subscribe
      end
    end
  end
  describe '#unsubscribe' do
    it 'unsubscribes' do
      expect(socket.ffi_delegate).to receive(:set_unsubscribe).with(subscription)
      socket.unsubscribe(subscription)
    end
  end
end

describe CZTop::Socket::XPUB do
  Given(:socket) { described_class.new }
  Then { socket }

  describe '#to_io' do
    Given { socket }
    Then do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::XSUB do
  Given(:socket) { described_class.new }
  Then { socket }

  describe '#to_io' do
    Given { socket }
    Then do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::PUSH do
  Given(:socket) { described_class.new }
  Then { socket }

  describe '#to_io' do
    Given { socket }
    Then do
      assert_kind_of IO, socket.to_io
    end
  end

  context 'integration' do
    let(:push) { CZTop::Socket::PUSH.new }
    let(:pull) { CZTop::Socket::PULL.new }
    i = 0
    let(:endpoint) { "inproc://socket_types_spec_push_#{i += 1}" }

    before do
      push.options.sndtimeo = 100
      pull.options.rcvtimeo = 100

      push.bind endpoint
      pull.connect endpoint
    end

    it 'can send message' do
      push << 'foobar'
      msg = pull.receive
      assert_equal ['foobar'], msg.to_a

      push << %w[foobar]
      msg = pull.receive
      assert_equal %w[foobar], msg.to_a

    end

    it 'can send message with empty frame' do
      expect(CZMQ::FFI::Zmsg).to receive(:send).with(CZMQ::FFI::Zmsg, push).and_call_original

      push << ''
    end
  end
end

describe CZTop::Socket::PULL do
  Given(:socket) { described_class.new }
  Then { socket }

  describe '#to_io' do
    Given { socket }
    Then do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::PAIR do
  i = 0
  let(:endpoint) { "inproc://socket_types_spec_#{i += 1}" }
  let(:binding_socket) { described_class.new("@#{endpoint}") }
  let(:connecting_socket) { described_class.new(">#{endpoint}") }

  it 'creates PAIR sockets' do
    binding_socket
    connecting_socket
  end

  it 'raises when more than 2 PAIR sockets are connected' do
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
