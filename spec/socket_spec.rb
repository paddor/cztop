require_relative 'spec_helper'

describe CZTop::Socket do
  i = 0
  let(:endpoint) { "inproc://endpoint_#{i+=1}" }
  let(:req_socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:rep_socket) { CZTop::Socket::REP.new(endpoint) }
  let(:binding_pair_socket) { CZTop::Socket::PAIR.new("@#{endpoint}") }
  let(:connecting_pair_socket) { CZTop::Socket::PAIR.new(">#{endpoint}") }

  it "creates low-level REP socket" do
    endpoint = "inproc://sock#{i}"
    sock = ::CZMQ::FFI::Zsock.new_rep(endpoint)
    refute_operator sock, :null?
  end

  it "creates low-level REQ socket" do
    sock = ::CZMQ::FFI::Zsock.new_req(endpoint)
    refute_operator sock, :null?
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

  it "allows creating a socket without providing an endpoint" do
    CZTop::Socket::PAIR.new
  end

  it "sends and waits for a signal" do
    s1 = connecting_pair_socket
    s2 = binding_pair_socket
    s1.signal 5
    assert_equal 5, s2.wait
  end

  it "raises when socket couldn't be created" do
    endpoint = "inproc://the_one_and_only"
    sock1 = CZTop::Socket::REP.new(endpoint)
    # there can only be one REP socket bound to one endpoint
    assert_raises(CZTop::InitializationError) do
      sock2 = CZTop::Socket::REP.new(endpoint)
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

#  it "sends and receives a string" do
#    req_socket.send_string "foobar"
#    assert_equal "foobar", rep_socket.receive_string
#    rep_socket.send_string "foobarbaz"
#    assert_equal "foobarbaz", req_socket.receive_string
#  end
end
