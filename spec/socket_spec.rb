require_relative 'spec_helper'


describe CZTop::Socket do
  i = 0
  let(:endpoint) { "inproc://endpoint_#{i+=1}" }
  let(:req_socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:rep_socket) { CZTop::Socket::REP.new(endpoint) }
  let(:binding_pair_socket) { CZTop::Socket::PAIR.new("@#{endpoint}") }
  let(:connecting_pair_socket) { CZTop::Socket::PAIR.new(">#{endpoint}") }

  # low-level binding
  describe ::CZMQ::FFI::Zsock do
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

  describe ".new_by_type" do
    context "given valid type" do
      let(:expected_class) { CZTop::Socket::PUSH }
      context "by integer" do
        let(:type) { CZTop::Socket::Types::PUSH }
        it "returns socket" do
          assert_kind_of Integer, type
          assert_kind_of expected_class, described_class.new_by_type(type)
        end
      end
      context "by symbol" do
        let(:type) { :PUSH }
        it "returns socket" do
          assert_kind_of expected_class, described_class.new_by_type(type)
        end
      end
    end

    context "given invalid type name" do
      context "by integer" do
        let(:type) { 99 } # non-existent type
        it "raises" do
          assert_raises(ArgumentError) { described_class.new_by_type(type) }
        end
      end
      context "by symbol" do
        let(:type) { :FOOBAR } # non-existent type
        it "raises" do
          assert_raises(NameError) { described_class.new_by_type(type) }
        end
      end
      context "by other kind" do
        # NOTE: No support for socket types as Strings for now.
        let(:type) { "PUB" }
        it "raises" do
          assert_raises(ArgumentError) { described_class.new_by_type(type) }
        end
      end
    end
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

  describe "ffi_delegate" do
    it "returns pointer to the real zsock" do
      refute req_socket.ffi_delegate.null?
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
        req_socket << content # REQ => REP
        assert_equal content, rep_socket.receive.frames.first.to_s
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

  describe "#connect"
  describe "#disconnect"
  describe "#bind"
  describe "#unbind"
  describe "#options"
  describe "#set_option"
  describe "#get_option"


  describe CZTop::Socket::Options do
  end

  describe CZTop::Socket::CLIENT do
  end
  describe CZTop::Socket::SERVER do
  end
  describe CZTop::Socket::REQ do
  end
  describe CZTop::Socket::REP do
  end
  describe CZTop::Socket::PUB do
  end
  describe CZTop::Socket::SUB do
  end
  describe CZTop::Socket::XPUB do
  end
  describe CZTop::Socket::XSUB do
  end
  describe CZTop::Socket::PUSH do
  end
  describe CZTop::Socket::PULL do
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
  describe CZTop::Socket::STREAM do
  end
end
