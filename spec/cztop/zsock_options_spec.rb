require_relative 'spec_helper'

describe CZTop::ZsockOptions do
  i = 0
  let(:endpoint) { "inproc://endpoint_#{i+=1}" }
  let(:socket) { CZTop::Socket::REQ.new(endpoint) }

  describe "#options" do
    let(:options) { socket.options }
    it "returns options proxy" do
      assert_kind_of CZTop::ZsockOptions::OptionsAccessor, options
    end

    it "changes the correct socket's options" do
      assert_same socket, options.zocket
    end
  end
end
