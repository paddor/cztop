require_relative 'spec_helper'

describe CZTop::SendReceiveMethods do
  let(:zocket) do
    o = Object.new
    o.extend CZTop::SendReceiveMethods
    o
  end
  describe "#send" do
    let(:content) { "foobar" }
    it "sends content" do
      msg = double("Message")
      expect(CZTop::Message).to receive(:coerce).with(content).and_return(msg)
      expect(msg).to receive(:send_to).with(zocket)
      zocket.send(content)
    end

    it "has alias #<<" do
      assert_operator zocket, :respond_to?, :<<
      assert_equal zocket.method(:send), zocket.method(:<<)
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
