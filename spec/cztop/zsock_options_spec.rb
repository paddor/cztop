require_relative 'spec_helper'

describe CZTop::ZsockOptions do
  i = 0
  let(:endpoint) { "inproc://endpoint_zsock_options_#{i+=1}" }
  let(:socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:options) { socket.options }

  describe "#options" do
    it "returns options proxy" do
      assert_kind_of CZTop::ZsockOptions::OptionsAccessor, options
    end

    it "changes the correct socket's options" do
      assert_same socket, options.zocket
    end
  end

  describe CZTop::ZsockOptions::OptionsAccessor do
    describe "sndhwm" do
      context "getting current value" do
        it "returns value" do
          assert_kind_of Integer, options.sndhwm
        end
      end
      context "setting new value" do
        let(:new_value) { 99 }
        before(:each) { options.sndhwm = new_value }
        it "sets new value" do
          assert_equal new_value, options.sndhwm
        end
      end
    end
    describe "rcvhwm" do
      context "getting current value" do
        it "returns value" do
          assert_kind_of Integer, options.rcvhwm
        end
      end
      context "setting new value" do
        let(:new_value) { 99 }
        before(:each) { options.rcvhwm = new_value }
        it "sets new value" do
          assert_equal new_value, options.rcvhwm
        end
      end
    end
  end
end
