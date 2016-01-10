require_relative 'spec_helper'
require 'tmpdir'
require 'pathname'

describe CZTop::Socket do
  include_examples "has FFI delegate"

  i = 0
  let(:endpoint) { "inproc://endpoint_socket_spec_#{i+=1}" }
  let(:req_socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:rep_socket) { CZTop::Socket::REP.new(endpoint) }
  let(:binding_pair_socket) { CZTop::Socket::PAIR.new("@#{endpoint}") }
  let(:connecting_pair_socket) { CZTop::Socket::PAIR.new(">#{endpoint}") }

  it "has Zsock options" do
    assert_operator described_class, :<, CZTop::ZsockOptions
  end

  it "has send/receive methods" do
    assert_operator described_class, :<, CZTop::SendReceiveMethods
  end

  it "has polymorphic Zsock methods" do
    assert_operator described_class, :<, CZTop::PolymorphicZsockMethods
  end

  describe "#initialize" do
    context "given invalid endpoint" do
      let(:endpoint) { "foo://bar" }
      it "raises" do
        assert_raises(CZTop::InitializationError) do
          CZTop::Socket::REP.new(endpoint)
        end
      end
    end

    context "given same binding endpoint to multiple REP sockets" do
      let(:endpoint) { "inproc://the_one_and_only" }
      let(:sock1) { CZTop::Socket::REP.new(endpoint) }
      before(:each) { sock1 }
      it "raises" do
        # there can only be one REP socket bound to one endpoint
        assert_raises(CZTop::InitializationError) do
          CZTop::Socket::REP.new(endpoint)
        end
      end
    end
  end

  describe "#<< and #receive" do
    context "given a sent content" do
      let(:content) { "foobar" }
      it "receives the content" do
        connecting_pair_socket << content # REQ => REP
        msg = binding_pair_socket.receive # REQ <= REP
        assert_equal content, msg.frames.first.to_s
      end
    end
  end

  describe "#CURVE_server!" do
    let(:certificate) { CZTop::Certificate.new }
    let(:options) { rep_socket.options }
    When do
      rep_socket.CURVE_server!(certificate)
    end
    Then { rep_socket.options.CURVE_server? }
    Then { options.CURVE_secretkey == certificate.secret_key }
    Then { options.CURVE_publickey == certificate.public_key }
  end

  describe "#CURVE_client!" do
    let(:tmpdir) do
      Pathname.new(Dir.mktmpdir("zsock_test"))
    end
    let(:path) { tmpdir + "server_cert.txt" }
    let(:server_cert) do
      # NOTE: ensure only public key is set
      CZTop::Certificate.new.save_public(path)
      CZTop::Certificate.load(path)
    end
    let(:client_cert) { CZTop::Certificate.new }
    let(:options) { req_socket.options }

    context "with client certificate" do
      before(:each) do
        req_socket.CURVE_client!(client_cert, server_cert)
      end

      it "sets client secret key" do
        assert_equal client_cert.secret_key, options.CURVE_secretkey
      end
      it "sets client public key" do
        assert_equal client_cert.public_key, options.CURVE_publickey
      end
      it "sets server's public key" do
        assert_equal server_cert.public_key, options.CURVE_serverkey
      end
      it "doesn't set CURVE server" do
        refute options.CURVE_server?
      end
      it "changes mechanism to :CURVE" do
        assert_equal :CURVE, options.mechanism
      end
    end
    context "with secret key in server certificate" do
      let(:server_cert) { CZTop::Certificate.new }
      it "raises" do # server's secret key compromised
        assert_raises(SecurityError) do
          req_socket.CURVE_client!(client_cert, server_cert)
        end
      end
    end
  end

  describe "#last_endpoint" do
    context "unbound socket" do
      let(:socket) { CZTop::Socket.new_by_type(:REP) }

      it "returns nil" do
        assert_nil socket.last_endpoint
      end
    end

    context "bound socket" do
      it "returns endpoint" do
        assert_equal endpoint, rep_socket.last_endpoint
      end
    end
  end

  describe "#connect" do
    Given(:socket) { rep_socket }
    context "with valid endpoint" do
      let(:another_endpoint) { "inproc://foo" }
      it "connects" do
        req_socket.connect(another_endpoint)
      end
    end
    context "with invalid endpoint" do
      Given(:another_endpoint) { "foo://bar" }
      When(:result) { socket.connect(another_endpoint) }
      Then { result == Failure(ArgumentError) }
    end
    it "does safe format handling" do
      expect(socket.ffi_delegate).to receive(:connect).with("%s", any_args).and_return(0)
      socket.connect(double("endpoint"))
    end
  end

  describe "#disconnect" do
    Given(:socket) { rep_socket }
    context "with valid endpoint" do
      it "disconnects" do
        expect(socket.ffi_delegate).to receive(:disconnect)
        socket.disconnect(endpoint)
      end
    end
    context "with invalid endpoint" do
      Given(:another_endpoint) { "foo://bar" }
      When(:result) { socket.disconnect(another_endpoint) }
      Then { result == Failure(ArgumentError) }
    end
    it "does safe format handling" do
      expect(socket.ffi_delegate).to receive(:disconnect).with("%s", any_args).and_return(0)
      socket.disconnect(double("endpoint"))
    end
  end

  describe "#bind" do
    Given(:socket) { rep_socket }
    context "with valid endpoint" do
      Then { assert_nil socket.last_tcp_port }
      context "with automatic TCP port selection endpoint" do
        Given(:another_endpoint) { "tcp://127.0.0.1:*" }
        When { socket.bind(another_endpoint) }
        Then { assert_kind_of Integer, socket.last_tcp_port }
        And { socket.last_tcp_port > 0 }
      end
      context "with explicit TCP port endpoint" do
        Given(:port) { rand(55_755..58_665) }
        Given(:another_endpoint) { "tcp://127.0.0.1:#{port}" }
        When { socket.bind(another_endpoint) }
        Then { socket.last_tcp_port == port }
      end
      context "with non-TCP endpoint" do
        Given(:another_endpoint) { "inproc://non_tcp_endpoint" }
        When { socket.bind(another_endpoint) }
        Then { assert_nil socket.last_tcp_port }
      end
    end
    context "with invalid endpoint" do
      Given(:another_endpoint) { "foo://bar" }
      When(:result) { socket.bind(another_endpoint) }
      Then { result == Failure(CZTop::Socket::Error) }
    end

    it "does safe format handling" do
      expect(socket.ffi_delegate).to receive(:bind).with("%s", any_args).and_return(0)
      socket.bind(double("endpoint"))
    end
  end

  describe "#unbind" do
    Given(:socket) { rep_socket }
    context "with valid endpoint" do
      it "unbinds" do
        expect(socket.ffi_delegate).to receive(:unbind)
        socket.unbind(endpoint)
      end
    end
    context "with invalid endpoint" do
      Given(:another_endpoint) { "bar://foo" }
      When(:result) { socket.unbind(another_endpoint) }
      Then { result == Failure(ArgumentError) }
    end
    it "does safe format handling" do
      expect(socket.ffi_delegate).to receive(:unbind).with("%s", any_args).and_return(0)
      socket.unbind(double("endpoint"))
    end
  end
end
