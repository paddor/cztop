# frozen_string_literal: true

require_relative 'test_helper'


class CZTopSocketTest < Minitest::Spec
  SUBJECT = CZTop::Socket
  include HasFFIDelegateExamples

  def endpoint
    @endpoint ||= "inproc://endpoint_socket_spec_#{SecureRandom.hex(8)}"
  end

  def req_socket
    @req_socket ||= CZTop::Socket::REQ.new(endpoint)
  end

  def rep_socket
    @rep_socket ||= CZTop::Socket::REP.new(endpoint)
  end

  def binding_pair_socket
    @binding_pair_socket ||= CZTop::Socket::PAIR.new("@#{endpoint}")
  end

  def connecting_pair_socket
    @connecting_pair_socket ||= CZTop::Socket::PAIR.new(">#{endpoint}")
  end

  it 'has Zsock options' do
    assert_operator CZTop::Socket, :<, CZTop::ZsockOptions
  end


  describe '.bind' do
    it 'creates a socket and binds to the endpoint' do
      rep = CZTop::Socket::REP.bind(endpoint)
      assert_equal endpoint, rep.last_endpoint
    end

    it 'passes through keyword arguments' do
      rep = CZTop::Socket::REP.bind(endpoint, curve: nil)
      assert_equal endpoint, rep.last_endpoint
    end

    it 'works on all socket types' do
      pub = CZTop::Socket::PUB.bind(endpoint)
      assert_equal endpoint, pub.last_endpoint
    end
  end


  describe '.connect' do
    before { CZTop::Socket::REP.bind(endpoint) }

    it 'creates a socket and connects to the endpoint' do
      req = CZTop::Socket::REQ.connect(endpoint)
      assert_instance_of CZTop::Socket::REQ, req
    end

    it 'passes through keyword arguments' do
      req = CZTop::Socket::REQ.connect(endpoint, curve: nil)
      assert_instance_of CZTop::Socket::REQ, req
    end

    it 'works with SUB prefix: kwarg' do
      pub = CZTop::Socket::PUB.bind("inproc://bind_connect_sub_test")
      sub = CZTop::Socket::SUB.connect("inproc://bind_connect_sub_test", prefix: 'weather')
      assert_instance_of CZTop::Socket::SUB, sub
    end
  end


  describe '#initialize' do
    describe 'given invalid endpoint' do
      def endpoint
        @endpoint ||= 'foo://bar'
      end

      it 'raises' do
        assert_raises(SystemCallError) do
          CZTop::Socket::REP.new(endpoint)
        end
      end
    end


    describe 'given same binding endpoint to multiple REP sockets' do
      def endpoint
        @endpoint ||= 'inproc://the_one_and_only'
      end

      def sock1
        @sock1 ||= CZTop::Socket::REP.new(endpoint)
      end
      before { sock1 }

      it 'raises' do
        # there can only be one REP socket bound to one endpoint
        assert_raises(SystemCallError) do
          CZTop::Socket::REP.new(endpoint)
        end
      end
    end
  end


  describe '#set_unbounded' do
    it 'sets sndhwm and rcvhwm to 0' do
      req_socket.set_unbounded
      assert_equal 0, req_socket.sndhwm
      assert_equal 0, req_socket.rcvhwm
    end
  end


  describe '#<< and #receive' do
    describe 'given a sent content' do
      def content
        @content ||= 'foobar'
      end

      it 'receives the content' do
        connecting_pair_socket << content
        msg = binding_pair_socket.receive
        assert_equal content, msg[0]
      end
    end
  end


  describe '#last_endpoint' do
    describe 'unbound socket' do
      def socket
        @socket ||= CZTop::Socket::REP.new
      end

      it 'returns nil' do
        assert_nil socket.last_endpoint
      end
    end


    describe 'bound socket' do
      it 'returns endpoint' do
        assert_equal endpoint, rep_socket.last_endpoint
      end
    end
  end


  describe '#connect' do
    def socket
      @socket ||= rep_socket
    end


    describe 'with valid endpoint' do
      def another_endpoint
        @another_endpoint ||= 'inproc://foo'
      end

      it 'connects' do
        req_socket.connect(another_endpoint)
      end
    end


    describe 'with invalid endpoint' do
      def another_endpoint
        @another_endpoint ||= 'foo://bar'
      end

      it 'raises' do
        assert_raises(ArgumentError) { socket.connect(another_endpoint) }
      end
    end

    it 'does safe format handling' do
      # format specifiers in endpoint should not be expanded
      assert_raises(ArgumentError) { socket.connect('tcp://%s:1234') }
    end
  end


  describe '#disconnect' do
    def socket
      @socket ||= rep_socket
    end


    describe 'with valid endpoint' do
      it 'disconnects' do
        connecting_socket = CZTop::Socket::REQ.new
        connecting_socket.connect(endpoint)
        connecting_socket.disconnect(endpoint)
      end
    end


    describe 'with invalid endpoint' do
      def another_endpoint
        @another_endpoint ||= 'foo://bar'
      end

      it 'raises' do
        assert_raises(ArgumentError) { socket.disconnect(another_endpoint) }
      end
    end

    it 'does safe format handling' do
      assert_raises(ArgumentError) { socket.disconnect('tcp://%s:1234') }
    end
  end


  describe '#close' do
    it 'nullifies ffi delegate' do
      rep_socket.close
      assert rep_socket.ffi_delegate.null?
    end


  end


  describe '#bind' do
    def socket
      @socket ||= rep_socket
    end


    describe 'with valid endpoint' do
      it 'has no last_tcp_port initially' do
        assert_nil socket.last_tcp_port
      end


      describe 'with automatic TCP port selection endpoint' do
        def another_endpoint
          @another_endpoint ||= 'tcp://127.0.0.1:*'
        end
        before { socket.bind(another_endpoint) }

        it 'sets last_tcp_port to a positive integer' do
          assert_kind_of Integer, socket.last_tcp_port
          assert_operator socket.last_tcp_port, :>, 0
        end
      end


      describe 'with explicit TCP port endpoint' do
        def port
          @port ||= rand(55_755..58_665)
        end

        def another_endpoint
          @another_endpoint ||= "tcp://127.0.0.1:#{port}"
        end
        before { socket.bind(another_endpoint) }

        it 'sets last_tcp_port to the specified port' do
          assert_equal port, socket.last_tcp_port
        end
      end


      describe 'with non-TCP endpoint' do
        def another_endpoint
          @another_endpoint ||= 'inproc://non_tcp_endpoint'
        end
        before { socket.bind(another_endpoint) }

        it 'has no last_tcp_port' do
          assert_nil socket.last_tcp_port
        end
      end
    end


    describe 'with invalid endpoint' do
      def another_endpoint
        @another_endpoint ||= 'foo://bar'
      end

      it 'raises' do
        assert_raises(SystemCallError) { socket.bind(another_endpoint) }
      end
    end

    it 'does safe format handling' do
      assert_raises(ArgumentError, SystemCallError) { socket.bind('tcp://%s:1234') }
    end
  end


  describe '#unbind' do
    def socket
      @socket ||= rep_socket
    end


    describe 'with valid endpoint' do
      it 'unbinds' do
        socket.unbind(endpoint)
      end
    end


    describe 'with invalid endpoint' do
      def another_endpoint
        @another_endpoint ||= 'bar://foo'
      end

      it 'raises' do
        assert_raises(ArgumentError) { socket.unbind(another_endpoint) }
      end
    end

    it 'does safe format handling' do
      assert_raises(ArgumentError) { socket.unbind('bar://%s') }
    end
  end


  describe '#inspect' do
    describe 'with native object alive' do
      it 'contains class name' do
        assert_match(/\A#<CZTop::Socket::[A-Z]\w+:.*>\z/, req_socket.inspect)
      end

      it 'contains native address' do
        assert_match(/:0x[[:xdigit:]]+\b/, req_socket.inspect)
      end

      it 'contains last endpoint' do
        assert_match(/\blast_endpoint=.+\b/, req_socket.inspect)
      end
    end


    describe 'with native object destroyed' do
      before { req_socket.close }

      it 'describes socket as invalid' do
        assert_match(/invalid/, req_socket.inspect)
      end
    end
  end
end
