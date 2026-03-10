# frozen_string_literal: true

require_relative 'spec_helper'
require 'tmpdir'
require 'pathname'


describe CZTop::Socket do
  include HasFFIDelegateExamples

  i = 0
  let(:endpoint) { "inproc://endpoint_socket_spec_#{i += 1}" }
  let(:req_socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:rep_socket) { CZTop::Socket::REP.new(endpoint) }
  let(:binding_pair_socket) { CZTop::Socket::PAIR.new("@#{endpoint}") }
  let(:connecting_pair_socket) { CZTop::Socket::PAIR.new(">#{endpoint}") }

  it 'has Zsock options' do
    assert_operator CZTop::Socket, :<, CZTop::ZsockOptions
  end

  it 'has polymorphic Zsock methods' do
    assert_operator CZTop::Socket, :<, CZTop::PolymorphicZsockMethods
  end


  describe '#initialize' do
    describe 'given invalid endpoint' do
      let(:endpoint) { 'foo://bar' }

      it 'raises' do
        assert_raises(SystemCallError) do
          CZTop::Socket::REP.new(endpoint)
        end
      end
    end


    describe 'given same binding endpoint to multiple REP sockets' do
      let(:endpoint) { 'inproc://the_one_and_only' }
      let(:sock1) { CZTop::Socket::REP.new(endpoint) }
      before { sock1 }

      it 'raises' do
        # there can only be one REP socket bound to one endpoint
        assert_raises(SystemCallError) do
          CZTop::Socket::REP.new(endpoint)
        end
      end
    end
  end


  describe '#<< and #receive' do
    describe 'given a sent content' do
      let(:content) { 'foobar' }

      it 'receives the content' do
        connecting_pair_socket << content
        msg = binding_pair_socket.receive
        assert_equal content, msg.frames.first.to_s
      end
    end
  end


  describe '#CURVE_server!' do
    before { skip 'requires CURVE' unless ::CZMQ::FFI::Zsys.has_curve }

    let(:certificate) { CZTop::Certificate.new }
    let(:options) { rep_socket.options }


    describe 'with valid certificate' do
      before do
        rep_socket.CURVE_server!(certificate)
      end

      it 'enables CURVE server' do
        assert rep_socket.options.CURVE_server?
      end

      it 'sets secret key' do
        assert_equal certificate.secret_key, options.CURVE_secretkey
      end

      it 'sets public key' do
        assert_equal certificate.public_key, options.CURVE_publickey
      end
    end


    describe 'with no secret key in certificate' do
      let(:certificate) do
        tmpdir = Pathname.new(Dir.mktmpdir('zsock_test'))
        path = tmpdir + 'server_cert.txt'
        # NOTE: ensure only public key is set
        CZTop::Certificate.new.save_public(path)
        CZTop::Certificate.load(path)
      end

      it 'raises' do
        assert_raises(ArgumentError) do
          rep_socket.CURVE_server!(certificate)
        end
      end
    end
  end


  describe '#CURVE_client!' do
    before { skip 'requires CURVE' unless ::CZMQ::FFI::Zsys.has_curve }

    let(:tmpdir) do
      Pathname.new(Dir.mktmpdir('zsock_test'))
    end
    let(:path) { tmpdir + 'server_cert.txt' }
    let(:server_cert) do
      # NOTE: ensure only public key is set
      CZTop::Certificate.new.save_public(path)
      CZTop::Certificate.load(path)
    end
    let(:client_cert) { CZTop::Certificate.new }
    let(:options) { req_socket.options }


    describe 'with client certificate' do
      before do
        req_socket.CURVE_client!(client_cert, server_cert)
      end

      it 'sets client secret key' do
        assert_equal client_cert.secret_key, options.CURVE_secretkey
      end

      it 'sets client public key' do
        assert_equal client_cert.public_key, options.CURVE_publickey
      end

      it "sets server's public key" do
        assert_equal server_cert.public_key, options.CURVE_serverkey
      end

      it "doesn't set CURVE server" do
        refute options.CURVE_server?
      end

      it 'changes mechanism to :CURVE' do
        assert_equal :CURVE, options.mechanism
      end
    end


    describe 'with secret key in server certificate' do
      let(:server_cert) { CZTop::Certificate.new }

      it 'raises' do # server's secret key compromised
        assert_raises(SecurityError) do
          req_socket.CURVE_client!(client_cert, server_cert)
        end
      end
    end


    describe 'with no secret key in certificate' do
      let(:client_cert) do
        # NOTE: ensure only public key is set
        path = tmpdir + 'client_cert.txt'
        CZTop::Certificate.new.save_public(path)
        CZTop::Certificate.load(path)
      end

      it 'raises' do
        assert_raises(SystemCallError) do
          req_socket.CURVE_client!(client_cert, server_cert)
        end
      end
    end
  end


  describe '#last_endpoint' do
    describe 'unbound socket' do
      let(:socket) { CZTop::Socket.new_by_type(:REP) }

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
    let(:socket) { rep_socket }


    describe 'with valid endpoint' do
      let(:another_endpoint) { 'inproc://foo' }

      it 'connects' do
        req_socket.connect(another_endpoint)
      end
    end


    describe 'with invalid endpoint' do
      let(:another_endpoint) { 'foo://bar' }

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
    let(:socket) { rep_socket }


    describe 'with valid endpoint' do
      it 'disconnects' do
        connecting_socket = CZTop::Socket::REQ.new
        connecting_socket.connect(endpoint)
        connecting_socket.disconnect(endpoint)
      end
    end


    describe 'with invalid endpoint' do
      let(:another_endpoint) { 'foo://bar' }

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
    let(:socket) { rep_socket }


    describe 'with valid endpoint' do
      it 'has no last_tcp_port initially' do
        assert_nil socket.last_tcp_port
      end


      describe 'with automatic TCP port selection endpoint' do
        let(:another_endpoint) { 'tcp://127.0.0.1:*' }
        before { socket.bind(another_endpoint) }

        it 'sets last_tcp_port to a positive integer' do
          assert_kind_of Integer, socket.last_tcp_port
          assert_operator socket.last_tcp_port, :>, 0
        end
      end


      describe 'with explicit TCP port endpoint' do
        let(:port) { rand(55_755..58_665) }
        let(:another_endpoint) { "tcp://127.0.0.1:#{port}" }
        before { socket.bind(another_endpoint) }

        it 'sets last_tcp_port to the specified port' do
          assert_equal port, socket.last_tcp_port
        end
      end


      describe 'with non-TCP endpoint' do
        let(:another_endpoint) { 'inproc://non_tcp_endpoint' }
        before { socket.bind(another_endpoint) }

        it 'has no last_tcp_port' do
          assert_nil socket.last_tcp_port
        end
      end
    end


    describe 'with invalid endpoint' do
      let(:another_endpoint) { 'foo://bar' }

      it 'raises' do
        assert_raises(SystemCallError) { socket.bind(another_endpoint) }
      end
    end

    it 'does safe format handling' do
      assert_raises(ArgumentError, SystemCallError) { socket.bind('tcp://%s:1234') }
    end
  end


  describe '#unbind' do
    let(:socket) { rep_socket }


    describe 'with valid endpoint' do
      it 'unbinds' do
        socket.unbind(endpoint)
      end
    end


    describe 'with invalid endpoint' do
      let(:another_endpoint) { 'bar://foo' }

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
