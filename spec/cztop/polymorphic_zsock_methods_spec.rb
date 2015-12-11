require_relative 'spec_helper'

describe CZTop::PolymorphicZsockMethods do
  i = 0
  let(:endpoint) { "inproc://endpoint_send_receive_method_spec_#{i+=1}" }
  let(:socket_a) { CZTop::Socket::PAIR.new("@#{endpoint}") }
  let(:socket_b) { CZTop::Socket::PAIR.new(">#{endpoint}") }

  describe "signals" do
    let (:status) { 5 }
    describe "#signal" do
      it "sends a signal" do
        socket_b.signal(status)
      end
    end

    describe "#wait" do
      it "waits for a signal" do
        socket_b.signal(status)
        assert_equal status, socket_a.wait
      end
    end
  end

  describe "#set_unbounded" do
    it "sets HWM to 0"
  end
end
