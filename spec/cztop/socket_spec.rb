require_relative 'spec_helper'

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
      it "raises" do
        sock1 = CZTop::Socket::REP.new(endpoint)
        # there can only be one REP socket bound to one endpoint
        assert_raises(CZTop::InitializationError) do
          sock2 = CZTop::Socket::REP.new(endpoint)
        end
      end
    end
  end

  describe "signals" do
    let (:signal_code) { 5 }
    describe "#signal" do
      it "sends a signal" do
        connecting_pair_socket.signal(signal_code)
      end
    end

    describe "#wait" do
      it "waits for a signal" do
        connecting_pair_socket.signal(signal_code)
        assert_equal signal_code, binding_pair_socket.wait
      end
    end
  end

  describe "#send" do
    let(:content) { "foobar" }
    it "sends content" do
      req_socket.send content # REQ => REP
    end

    it "has alias #<<" do
      req_socket << content # REQ => REP
    end
  end

  describe "#receive" do
    context "given a sent content" do
      let(:content) { "foobar" }
      it "receives the content" do
        connecting_pair_socket << content # REQ => REP
        assert_equal content, binding_pair_socket.receive.frames.first.to_s
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
    context "with valid endpoint" do
      let(:another_endpoint) { "inproc://foo" }
      it "connects" do
        req_socket.connect(another_endpoint)
      end
    end
    context "with invalid endpoint" do
      let(:another_endpoint) { "bar://foo" }
      it "raises" do
        assert_raises(ArgumentError) do
          req_socket.connect(another_endpoint)
        end
      end
    end
  end

  describe "#disconnect" do
    context "with valid endpoint" do
      it "disconnects" do
        expect(req_socket.ffi_delegate).to receive(:disconnect)
        req_socket.disconnect(endpoint)
      end
    end
    context "with invalid endpoint" do
      let(:another_endpoint) { "bar://foo" }
      it "raises" do
        assert_raises(ArgumentError) do
          req_socket.disconnect(another_endpoint)
        end
      end
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
        Given(:port) { 55755 }
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
  end

  describe "#unbind" do
    context "with valid endpoint" do
      it "unbinds" do
        expect(req_socket.ffi_delegate).to receive(:unbind)
        req_socket.unbind(endpoint)
      end
    end
    context "with invalid endpoint" do
      let(:another_endpoint) { "bar://foo" }
      it "raises" do
        assert_raises(ArgumentError) do
          req_socket.unbind(another_endpoint)
        end
      end
    end
  end
end
