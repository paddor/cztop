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
    let(:socket) { CZTop::Socket.new_by_type(type) }
    describe 'given valid type' do
      let(:expected_class) { CZTop::Socket::PUSH }
      describe 'by integer' do
        let(:type) { CZTop::Socket::Types::PUSH }
        it 'returns socket' do
          assert_kind_of Integer, type
          assert_kind_of expected_class, socket
        end
      end
      describe 'by symbol' do
        let(:type) { :PUSH }
        it 'returns socket' do
          assert_kind_of expected_class, socket
        end
      end
    end

    describe 'given invalid type name' do
      describe 'by integer' do
        let(:type) { 99 } # non-existent type
        it 'raises' do
          assert_raises(ArgumentError) { socket }
        end
      end
      describe 'by symbol' do
        let(:type) { :FOOBAR } # non-existent type
        it 'raises' do
          assert_raises(NameError) { socket }
        end
      end
      describe 'by string' do
        # NOTE: No support for Strings as socket types for now.
        let(:type) { 'PUB' }
        it 'raises' do
          assert_raises(ArgumentError) { socket }
        end
      end
      describe 'by Socket::* class' do
        # NOTE: No support for socket Socket::* classes as types for now.
        let(:type) { CZTop::Socket::PUB }
        it 'raises' do
          assert_raises(ArgumentError) { socket }
        end
      end
    end
  end
end

describe CZTop::Socket::CLIENT do
  include ZMQHelper
  before { skip 'requires CZMQ drafts' unless has_czmq_drafts? }

  let(:client) do
    CZTop::Socket::CLIENT.new.tap do |client|
      client.connect endpoint
    end
  end

  let(:server) do
    CZTop::Socket::SERVER.new.tap do |server|
      server.bind endpoint
    end
  end
  i = 54_578
  let(:endpoint) { "inproc://client_spec_#{i += 1}" }

  it 'instantiates' do
    client
  end

  describe 'while connected' do
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

    describe 'when sending multi-part message' do
      it 'raises' do
        assert_raises(ArgumentError) do
          client << %w[foo bar]
        end
      end
    end
  end
end

describe CZTop::Socket::SERVER do
  include ZMQHelper
  before { skip 'requires CZMQ drafts' unless has_czmq_drafts? }

  let(:server) { CZTop::Socket::SERVER.new }

  it 'instantiates' do
    server
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, server.to_io
    end
  end

  describe 'when communicating' do
    i = 58_578
    let(:endpoint) { "inproc://server_spec_#{i += 1}" }
    let(:server_sndtimeo) { 50 }
    let(:server) do
      CZTop::Socket::SERVER.new.tap do |s|
        s.options.sndtimeo = server_sndtimeo
        s.bind(endpoint)
      end
    end
    let(:client_sndtimeo) { 50 }
    let(:client) do
      CZTop::Socket::CLIENT.new.tap do |s|
        s.options.sndtimeo = 50
        s.connect(endpoint)
      end
    end
    let(:msg_content) { 'FOO' }
    let(:routing_id) { 23_456 }
    let(:msg) { CZTop::Message.new(msg_content) }
    let(:received_msg) { server.receive }

    describe 'when receiving message from CLIENT' do
      before { client << msg_content }
      it 'receives message with routing_id' do
        assert_equal msg_content, received_msg[0].to_s
        assert_operator received_msg.routing_id, :>, 0
      end
    end

    describe 'when responding to a message from CLIENT' do
      let(:response) { CZTop::Message.new('BAR') }

      before do
        client << msg_content
        received_msg
      end

      describe 'with routing_id set' do
        it 'delivers response to client' do
          response.routing_id = received_msg.routing_id
          server << response
          assert_equal 'BAR', client.receive[0]
        end
      end

      describe 'with two responses with routing_id set' do
        let(:second_response) { CZTop::Message.new('BAZ') }
        it 'delivers both responses' do
          response.routing_id = received_msg.routing_id
          second_response.routing_id = received_msg.routing_id
          server << response << second_response
          assert_equal 'BAR', client.receive[0]
          assert_equal 'BAZ', client.receive[0]
        end
      end

      describe 'with wrong routing_id set' do
        describe 'with SERVER SNDTIMEO set' do
          let(:server_timeo) { 50 }
          it 'raises' do
            response.routing_id = 1234 # wrong routing_id
            assert_raises(SocketError) { server << response }
          end
        end
        describe 'with no SERVER SNDTIMEO set' do
          let(:server_timeo) { 0 }
          it 'raises' do
            response.routing_id = 1234 # wrong routing_id
            assert_raises(SocketError) { server << response }
          end
        end
      end

      describe 'without routing_id set' do
        it 'raises' do
          assert_raises(SocketError) { server << response }
        end
      end

      describe 'with disconnected CLIENT' do
        it 'raises' do
          client.disconnect(endpoint)
          response.routing_id = received_msg.routing_id
          assert_raises(IO::EAGAINWaitWritable) { server << response }
        end
      end

      describe 'with multi-part response' do
        let(:response) { CZTop::Message.new(%w[BAR BAZ]) }
        it 'raises' do
          response.routing_id = received_msg.routing_id
          assert_raises(ArgumentError) { server << response }
        end
      end
    end

    describe 'when SERVER tries to initiate a conversation' do
      it 'raises' do
        client
        server
        msg.routing_id = 1234 # fake routing_id
        assert_raises(SocketError) { server << msg }
      end
    end
  end
end

describe CZTop::Socket::RADIO do
  include ZMQHelper
  before { skip 'requires CZMQ drafts' unless has_czmq_drafts? }

  let(:socket) { CZTop::Socket::RADIO.new }

  it 'instantiates' do
    socket
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::DISH do
  include ZMQHelper
  before { skip 'requires CZMQ drafts' unless has_czmq_drafts? }

  i = 0
  let(:endpoint) { "inproc://radio-dish_spec_#{i += 1}" }
  let(:timeout) { 20 }
  let(:radio) do
    CZTop::Socket::RADIO.new.tap do |s|
      s.options.sndtimeo = timeout
      s.bind(endpoint)
    end
  end
  let(:dish) do
    CZTop::Socket::DISH.new.tap do |s|
      s.options.rcvtimeo = timeout
      s.connect(endpoint)
    end
  end
  let(:group) { 'group1' }

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, dish.to_io
    end
  end

  describe '#join' do
    describe 'given a message sent to a joined group' do
      it 'receives the message' do
        dish.join group
        msg = CZTop::Frame.new('foo').tap { |f| f.group = group }
        radio << msg
        received = dish.receive
        assert_equal group, received.frames[0].group
        assert_equal 'foo', received[0]
      end
    end

    describe 'given a message sent to an unjoined group' do
      it 'times out' do
        dish.join group
        msg = CZTop::Frame.new('foo').tap { |f| f.group = 'group2' }
        radio << msg
        assert_raises(IO::TimeoutError) { dish.receive }
      end
    end

    describe 'given an invalid group name' do
      let(:group) { 'x' * 256 }
      it 'raises' do
        assert_raises(ArgumentError) { dish.join group }
      end
    end

    describe 'given an already joined group' do
      let(:group) { 'group1' }
      it 'raises' do
        dish.join group
        assert_raises(ArgumentError) { dish.join group }
      end
    end
  end

  describe '#leave' do
    describe 'leaving a previously joined group' do
      let(:group) { 'group1' }
      it 'leaves without error' do
        dish.join group
        dish.leave group
      end
    end

    describe 'leaving an unjoined group' do
      let(:unjoined_group) { 'group1' }
      it 'raises' do
        assert_raises(ArgumentError) { dish.leave unjoined_group }
      end
    end
  end
end

describe CZTop::Socket::SCATTER do
  include ZMQHelper
  before { skip 'requires CZMQ drafts' unless has_czmq_drafts? }

  let(:socket) { CZTop::Socket::SCATTER.new }
  it 'instantiates' do
    socket
  end
end

describe CZTop::Socket::GATHER do
  include ZMQHelper
  before { skip 'requires CZMQ drafts' unless has_czmq_drafts? }

  i = 0
  let(:endpoint) { "inproc://scatter-gather_spec_#{i += 1}" }
  let(:timeout) { 20 }
  let(:scatter) do
    CZTop::Socket::SCATTER.new.tap do |s|
      s.options.sndtimeo = timeout
      s.bind(endpoint)
    end
  end
  let(:gather) do
    CZTop::Socket::GATHER.new.tap do |s|
      s.options.rcvtimeo = timeout
      s.connect(endpoint)
    end
  end

  describe 'given message from SCATTER' do
    it 'receives message' do
      gather
      scatter << 'foo'
      msg = gather.receive
      assert_equal 'foo', msg.to_a[0]
    end
  end

  describe 'given message from SCATTER and multiple GATHER sockets' do
    it 'delivers to only one gather socket' do
      gather
      gather2 = CZTop::Socket::GATHER.new.tap do |s|
        s.options.rcvtimeo = timeout
        s.connect(endpoint)
      end
      scatter << 'foo'
      result1 = begin; gather.receive; rescue => e; e; end
      result2 = begin; gather2.receive; rescue => e; e; end
      timeout_occurred = result1.is_a?(IO::TimeoutError) || result2.is_a?(IO::TimeoutError)
      message_received = result1.is_a?(CZTop::Message) || result2.is_a?(CZTop::Message)
      assert timeout_occurred
      assert message_received
    end
  end
end

describe CZTop::Socket::REQ do
  let(:socket) { CZTop::Socket::REQ.new }
  it 'instantiates' do
    socket
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
    end
  end

  describe 'integration' do
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
  let(:socket) { CZTop::Socket::REP.new }
  it 'instantiates' do
    socket
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::DEALER do
  let(:socket) { CZTop::Socket::DEALER.new }
  it 'instantiates' do
    socket
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::ROUTER do
  let(:socket) { CZTop::Socket::ROUTER.new }
  it 'instantiates' do
    socket
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
    end
  end

  describe '#send_to' do
    let(:receiver) { 'mike' }
    let(:content) { 'foobar' }
    it 'sends message to receiver' do
      sent = nil
      socket.stub(:<<, ->(msg) { sent = msg }) do
        socket.send_to(receiver, content)
      end
      assert_equal [receiver, '', content], sent.to_a
    end
  end

  describe 'with ZMQ_ROUTER_MANDATORY flag set' do
    before do
      socket.options.router_mandatory = true
    end

    describe 'when connected' do
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

      describe 'for unroutable message' do
        let(:msg_with_wrong_identity) { ['wrong_id', '', content] }

        it 'raises' do
          assert_raises(SocketError) { socket << msg_with_wrong_identity }
        end
      end

      describe 'for routable message' do
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
  let(:socket) { CZTop::Socket::PUB.new }
  it 'instantiates' do
    socket
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::SUB do
  let(:socket) { CZTop::Socket::SUB.new }
  it 'instantiates' do
    socket
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
    end
  end

  let(:subscription) { 'test_prefix' }

  describe 'with subscription' do
    it 'subscribes' do
      called_with = nil
      original = ::CZMQ::FFI::Zsock.method(:new_sub)
      ::CZMQ::FFI::Zsock.stub(:new_sub, ->(*args) { called_with = args; original.call(*args) }) do
        CZTop::Socket::SUB.new(nil, subscription)
      end
      assert_equal [nil, subscription], called_with
    end
  end

  describe '#subscribe' do
    describe 'with subscription prefix' do
      it 'subscribes' do
        socket.subscribe(subscription)
      end
    end
    describe 'without subscription prefix' do
      it 'subscribes to everything' do
        socket.subscribe
      end
    end
  end

  describe '#unsubscribe' do
    it 'unsubscribes' do
      socket.subscribe(subscription)
      socket.unsubscribe(subscription)
    end
  end
end

describe CZTop::Socket::XPUB do
  let(:socket) { CZTop::Socket::XPUB.new }
  it 'instantiates' do
    socket
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::XSUB do
  let(:socket) { CZTop::Socket::XSUB.new }
  it 'instantiates' do
    socket
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::PUSH do
  let(:socket) { CZTop::Socket::PUSH.new }
  it 'instantiates' do
    socket
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
    end
  end

  describe 'integration' do
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
      push << ''
      msg = pull.receive
      assert_equal [''], msg.to_a
    end
  end
end

describe CZTop::Socket::PULL do
  let(:socket) { CZTop::Socket::PULL.new }
  it 'instantiates' do
    socket
  end

  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
    end
  end
end

describe CZTop::Socket::PAIR do
  i = 0
  let(:endpoint) { "inproc://socket_types_spec_#{i += 1}" }
  let(:binding_socket) { CZTop::Socket::PAIR.new("@#{endpoint}") }
  let(:connecting_socket) { CZTop::Socket::PAIR.new(">#{endpoint}") }

  it 'creates PAIR sockets' do
    binding_socket
    connecting_socket
  end

  it 'raises when more than 2 PAIR sockets are connected' do
    binding_socket
    connecting_socket
    assert_raises(SystemCallError) do
      CZTop::Socket::PAIR.new("@#{endpoint}")
    end
    assert_raises do
      CZMQ::Socket::PAIR.new(">#{endpoint}")
    end
  end
end

describe CZTop::Socket::STREAM do
  let(:socket) { CZTop::Socket::STREAM.new }
  it 'instantiates' do
    socket
  end
end
