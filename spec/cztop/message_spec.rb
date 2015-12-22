require_relative 'spec_helper'

describe CZTop::Message do
  include_examples "has FFI delegate"
  let(:msg) { described_class.new }

  describe "#initialize" do
    subject { CZTop::Message.new }
    it "is empty" do
      assert_empty subject
    end
    it "has content size zero" do
      assert_equal 0, subject.content_size
    end

    context "with initial string" do
      let(:content) { "foo" }
      subject { described_class.new(content) }
      it "gets that string" do
        assert_equal content, subject.frames.first.to_s
      end

      it "has non-zero content size" do
        assert_operator subject.content_size, :>, 0
      end

      it "has one frame" do
        assert_equal 1, subject.frames.count
      end
    end

    context "with array of strings" do
      let(:parts) { [ "foo", "", "bar"] }
      let(:msg) { described_class.new(parts) }
      it "takes them as frames" do
        assert_equal parts.size, msg.size
        assert_equal parts, msg.frames.map(&:to_s)
      end
    end
  end

  describe ".coerce" do
    context "with a Message" do
      it "takes the Message as is" do
        assert_same msg, described_class.coerce(msg)
      end
    end

    context "with a String" do
      let(:content) { "foobar" }
      let(:coerced_msg) { described_class.coerce(content) }
      it "creates a new Message from the String" do
        assert_kind_of described_class, coerced_msg
        assert_equal 1, coerced_msg.size
        assert_equal content, coerced_msg.frames.first.to_s
      end
    end

    context "with a Frame" do
      Given(:frame_content) { "foobar special content" }
      Given(:frame) { CZTop::Frame.new(frame_content) }
      When(:coerced_msg) { described_class.coerce(frame) }
      Then { coerced_msg.kind_of? described_class }
      And { coerced_msg.size == 1 }
      And { coerced_msg.frames.first.to_s == frame_content }
    end

    context "with array of strings" do
      let(:parts) { [ "foo", "", "bar"] }
      let(:coerced_msg) { described_class.coerce(parts) }
      it "takes them as frames" do
        assert_equal parts.size, coerced_msg.size
        assert_equal parts, coerced_msg.frames.map(&:to_s)
      end
    end

    context "given something else" do
      Given(:something) { Object.new }
      When(:result) { described_class.coerce(something) }
      Then { result == Failure(ArgumentError) }
    end
  end

  describe "#<<" do
    Then { msg.size == 0 }
    context "with a string" do
      Given(:obj) { "foo" }
      When { msg << obj }
      Then { msg.size == 1 }
    end
    context "with a frame" do
      Given(:obj) { CZTop::Frame.new("foo") }
      When { msg << obj }
      Then { msg.size == 1 }
    end
    context "with something else" do
      Given(:obj) { Object.new }
      When(:result) { msg << obj }
      Then { result == Failure(ArgumentError) }
    end
  end

  describe "#send_to" do
    let(:delegate) { msg.ffi_delegate }
    let(:destination) { double "destination socket" }
    it "sends its delegate to the destination" do
      expect(CZMQ::FFI::Zmsg).to receive(:send).with(delegate, destination)
      msg.send_to(destination)
    end
  end

  describe ".receive_from" do
    let(:dlg) { msg.ffi_delegate }
    let(:received_message) { CZTop::Message.receive_from(src) }
    let(:src) { double "source" }
    it "receives message from source" do
      expect(CZMQ::FFI::Zmsg).to(receive(:recv).with(src).and_return(dlg))
      assert_kind_of CZTop::Message, received_message
      refute_same msg, received_message
      assert_same msg.ffi_delegate, received_message.ffi_delegate
    end
  end

  describe "#routing_id" do
    context "with no routing ID set" do
      Then { msg.routing_id == 0 }
    end
    context "with routing ID set" do
      Given(:routing_id) { 12345 }
      When { msg.routing_id = routing_id }
      Then { msg.routing_id == routing_id }
    end
  end

  describe "#routing_id=" do
    context "with valid routing ID" do
      # code duplication for completeness' sake
      Given(:new_routing_id) { 123456 }
      When { msg.routing_id = new_routing_id }
      Then { msg.routing_id == new_routing_id }
    end

    context "with negative routing ID" do
      Given(:new_routing_id) { -123456 }
      When(:result) { msg.routing_id = new_routing_id }
      Then { result == Failure(RangeError) }
    end

    context "with too big routing ID" do
      Given(:new_routing_id) { 123456345676543456765 }
      When(:result) { msg.routing_id = new_routing_id }
      Then { result == Failure(RangeError) }
    end
  end
end
