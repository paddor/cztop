require_relative '../spec_helper'

describe CZTop::Beacon do
  subject { described_class.new }
  let(:actor) { subject.actor }
  after(:each) { subject.terminate }

  describe "CZTop::Beacon::ZBEACON_FPTR" do
    it "points to a dynamic library symbol" do
      assert_kind_of FFI::DynamicLibrary::Symbol, CZTop::Beacon::ZBEACON_FPTR
    end
  end

  describe "#verbose!" do
    it "sends correct message to actor" do
      expect(CZMQ::FFI::Zstr).to receive(:send).with(actor, "VERBOSE")
      subject.verbose!
    end
  end
  describe "#configure" do
    let(:port) { 9999 }
    let(:hostname) { "example.com" }
    it "sends correct message to actor" do
      expect(CZMQ::FFI::Zsock).to receive(:send).with(actor, kind_of(String), "CONFIGURE", port)
      expect(CZMQ::FFI::Zstr).to(
        receive(:recv).with(actor).and_return(hostname))
      subject.configure(port)
    end
    context "when system doesn't support UDP broadcasts" do
      let(:hostname) { "" }
      it "raises" do
        allow(CZMQ::FFI::Zsock).to receive(:send)
        expect(CZMQ::FFI::Zstr).to(
          receive(:recv).with(actor).and_return(hostname))
        assert_raises(CZTop::Beacon::Error) do
          subject.configure(port)
        end
      end
    end
  end
  describe "#publish" do
    let(:data) { "foobar data" }
    let(:data_size) { data.bytesize }
    let(:interval) { 1000 }
    it "sends correct message to actor" do
      expect(CZMQ::FFI::Zsock).to(
        receive(:send).with(actor, kind_of(String), "PUBLISH", data,
                            data_size, interval))
      subject.publish(data, interval)
    end
    context "with data too long" do
      let(:data) { "x" * 256 } # max = 255 bytes
      it "raises" do
        assert_raises(CZTop::Beacon::Error) do
          subject.publish(data, interval)
        end
      end
    end
  end
  describe "#silence" do
    it "sends correct message to actor" do
      expect(CZMQ::FFI::Zstr).to receive(:sendx).with(actor, "SILENCE", nil)
      subject.silence
    end
  end
  describe "#subscribe" do
    let(:filter) { "foo filter" }
    let(:filter_size) { filter.bytesize }
    it "sends correct message to actor" do
      expect(CZMQ::FFI::Zsock).to(
        receive(:send).with(actor, kind_of(String), "SUBSCRIBE", filter,
                            filter_size))
      subject.subscribe(filter)
    end
  end
  describe "#listen" do
    it "sends correct message to actor" do
      expect(CZMQ::FFI::Zsock).to(
        receive(:send).with(actor, kind_of(String), "SUBSCRIBE", nil, 0))
      subject.listen
    end
  end
  describe "#unsubscribe" do
    it "sends correct message to actor" do
      expect(CZMQ::FFI::Zstr).to receive(:sendx).with(actor, "UNSUBSCRIBE",
                                                      nil)
      subject.unsubscribe
    end
  end
  describe "#receive" do
    let(:msg) { double("message") }
    it "receives a message from actor" do
      expect(CZTop::Message).to(
        receive(:receive_from).with(actor).and_return(msg))
      assert_equal msg, subject.receive
    end
  end
end
