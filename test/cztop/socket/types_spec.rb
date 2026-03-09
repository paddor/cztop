# frozen_string_literal: true

require_relative '../../spec_helper'

describe CZTop::Socket::Types do
  it 'has constants' do
    %i[PAIR PUB SUB REQ REP DEALER ROUTER PULL PUSH XPUB XSUB STREAM].each do |name|
      assert_operator CZTop::Socket::Types, :const_defined?, name
    end
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
