require_relative 'spec_helper'

describe CZTop::Socket do
  i = 0
  let(:endpoint) { "inproc://endpoint_#{i+=1}" }
  let(:req_socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:rep_socket) { CZTop::Socket::REP.new(endpoint) }
  let(:binding_pair_socket) { CZTop::Socket::PAIR.new("@#{endpoint}") }
  let(:connecting_pair_socket) { CZTop::Socket::PAIR.new(">#{endpoint}") }

  describe "low-level binding" do
    it "creates REP Zsock" do
      endpoint = "inproc://sock#{i}"
      sock = ::CZMQ::FFI::Zsock.new_rep(endpoint)
      refute_operator sock, :null?
    end

    it "creates REQ Zsock" do
      sock = ::CZMQ::FFI::Zsock.new_req(endpoint)
      refute_operator sock, :null?
    end
  end


  describe CZTop::Socket::PAIR do

    it "creates PAIR sockets" do
      binding_pair_socket
      connecting_pair_socket
    end

    it "raises when more than 2 PAIR sockets are connected" do
      binding_pair_socket
      connecting_pair_socket
      assert_raises(CZTop::InitializationError) do
        CZTop::Socket::PAIR.new("@#{endpoint}")
      end
  #    assert_raises do
  #      CZMQ::Socket::PAIR.new(">#{endpoint}")
  #    end
    end

  end

  describe "#initialize" do
    context "given no endpoint" do
      subject { CZTop::Socket::PAIR.new }
      it "creates a socket" do
        subject
      end
    end

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

#  it "creates a REQ socket" do
#    refute_nil req_socket
#  end
#
#  it "has an endpoint" do
#    another_endpoint = "inproc://foobar"
#    rep_socket.bind(another_endpoint)
#    assert_equal another_endpoint, rep_socket.endpoint
#  end
#
#  it "has a delegate" do
#    refute_nil req_socket.delegate
#  end
#
#  it "deletage has a pointer to the real zsock" do
#    refute req_socket.delegate.null?
#  end
#
#  it "creates a REP socket" do
#    refute_nil rep_socket
#  end

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
        req_socket << content # REQ => REP
        assert_equal content, rep_socket.receive.frames.first.to_s
      end
    end
  end
end
