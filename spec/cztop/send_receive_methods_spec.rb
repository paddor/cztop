require_relative 'spec_helper'

describe CZTop::SendReceiveMethods do
  let(:zocket) do
    o = Object.new
    o.extend CZTop::SendReceiveMethods
    o
  end
  describe "#<<" do
    context "when sending message" do
      let(:content) { "foobar" }
      let(:msg) { double("Message") }
      before do
        expect(CZTop::Message).to receive(:coerce).with(content).and_return(msg)
        expect(msg).to receive(:send_to).with(zocket)
      end

      it "sends content" do
        zocket << content
      end

      it "returns self" do # so it can be chained
        assert_same zocket, zocket << content
      end
    end
  end

  describe "#receive" do
    context "given a sent content" do
      let(:content) { "foobar" }
      it "receives the content" do
        msg = double
        expect(CZTop::Message).to(
          receive(:receive_from).with(zocket).and_return(msg))
        assert_same msg, zocket.receive
      end
    end
  end
end
