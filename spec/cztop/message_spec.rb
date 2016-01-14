require_relative 'spec_helper'

describe CZTop::Message do
  include_examples "has FFI delegate"
  let(:msg) { CZTop::Message.new }

  describe "#initialize" do
    subject { CZTop::Message.new }

    context "with initial string" do
      let(:content) { "foo" }
      subject { described_class.new(content) }
      it "sets content" do
        assert_equal content, subject.frames.first.to_s
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
    Given(:msg) { CZTop::Message.new "foo" }
    Then { msg.size == 1 }
    context "with a string" do
      Given(:frame) { "bar" }
      When { msg << frame }
      Then { msg.size == 2 }
      And { msg.to_a == %w[foo bar] }
    end
    context "with a frame" do
      Given(:frame) { CZTop::Frame.new("bar") }
      When { msg << frame }
      Then { msg.size == 2 }
      And { msg.to_a == %w[foo bar] }
    end
    context "with something else" do
      Given(:frame) { Object.new }
      When(:result) { msg << frame }
      Then { result == Failure(ArgumentError) }
    end
    context "method chaining" do
      When { msg << "FOO" << "BAR" }
      Then { msg.to_a == %w[ foo FOO BAR ] }
    end
  end

  describe "#prepend" do
    Given(:msg) { CZTop::Message.new "foo" }
    Then { msg.size == 1 }
    context "with a string" do
      Given(:frame) { "bar" }
      When { msg.prepend frame }
      Then { msg.size == 2 }
      And { msg.to_a == %w[bar foo] }
    end
    context "with a frame" do
      Given(:frame) { CZTop::Frame.new("bar") }
      When { msg.prepend frame }
      Then { msg.size == 2 }
      And { msg.to_a == %w[bar foo] }
    end
    context "with something else" do
      Given(:frame) { Object.new }
      When(:result) { msg.prepend frame }
      Then { result == Failure(ArgumentError) }
    end
  end

  describe "#pop" do
    before(:each) { subject << "FOO" << "BAR" }
    it "returns first part" do
      assert_equal "FOO", subject.pop
    end
    it "removes it from message" do
      subject.pop
      assert_equal %w[BAR], subject.to_a
    end
  end

  describe "#send_to" do
    let(:delegate) { msg.ffi_delegate }
    let(:destination) { double "destination socket" }
    context "when successful" do
      after(:each) { msg.send_to(destination) }
      it "sends its delegate to the destination" do
        expect(CZMQ::FFI::Zmsg).to receive(:send).with(delegate, destination)
          .and_return(0)
      end
    end
    context "when NOT successful" do
      before(:each) do
        expect(CZMQ::FFI::Zmsg).to receive(:send).with(delegate, destination)
          .and_return(-1)
        expect(CZMQ::FFI::Errors).to receive(:errno)
          .and_return(errno)
      end
      context "with sndtimeo reached" do
        let(:errno) { Errno::EAGAIN::Errno }
        it "raises IO::EAGAINWaitWritable" do
          assert_raises(IO::EAGAINWaitWritable) { msg.send_to(destination) }
        end
      end
      context "with host unreachable" do
        let(:errno) { Errno::EHOSTUNREACH::Errno }
        it "raises IO::EHOSTUNREACH" do
          assert_raises(Errno::EHOSTUNREACH) { msg.send_to(destination) }
        end
      end
      context "with other error" do
        let(:errno) { Errno::EINVAL::Errno }
        it "raises RuntimeError" do
          assert_raises(SystemCallError) { msg.send_to(destination) }
        end
      end
    end
  end

  describe ".receive_from" do
    let(:msg_delegate) { msg.ffi_delegate }
    let(:received_message) { CZTop::Message.receive_from(src) }
    let(:src) { double "source" }
    context "when successful" do
      it "receives message from source" do
        expect(CZMQ::FFI::Zmsg).to receive(:recv).with(src)
          .and_return(msg_delegate)
        assert_kind_of CZTop::Message, received_message
        assert_same msg.ffi_delegate, received_message.ffi_delegate
      end
    end

    context "when NOT successful" do
      let(:nullptr) { ::FFI::Pointer::NULL }
      before(:each) do
        expect(CZMQ::FFI).to receive(:zmsg_recv).and_return(nullptr)
        expect(CZMQ::FFI::Errors).to receive(:errno)
          .and_return(errno)
      end
      context "when interrupted" do
        let(:errno) { Errno::EINTR::Errno }
        it "raises Interrupt" do
          assert_raises(Interrupt) { received_message }
        end
      end
      context "with rcvtimeo reached" do
        let(:errno) { Errno::EAGAIN::Errno }
        it "raises IO::EAGAINWaitReadable" do
          assert_raises(IO::EAGAINWaitReadable) { received_message }
        end
      end
      context "with other error" do
        let(:errno) { Errno::EINVAL::Errno }
        it "raises RuntimeError" do
          assert_raises(SystemCallError) { received_message }
        end
      end
    end
  end

  describe "#empty?" do
    context "with no content" do
      Then { subject.empty? }
    end
    context "with content" do
      subject { CZTop::Message.new "foo" }
      Then { ! subject.empty? }
    end
  end

  describe "#content_size" do
    context "with no content" do
      it "has content size zero" do
        assert_equal 0, subject.content_size
      end
    end
    context "with content" do
      subject { CZTop::Message.new "foo" }
      it "returns correct content size" do
        assert_equal 3, subject.content_size
      end
    end
  end

  describe "#to_a" do
    context "with no frames" do
      Then { [] == subject.to_a }
    end
    context "with frames" do
      Given(:parts) { %w[ foo bar ] }
      subject { CZTop::Message.new parts }
      Then { parts == subject.to_a }
    end
  end

  describe "#inspect" do
    let(:s) { msg.inspect}
    context "with empty message" do
      it "contains class name" do
        assert_match /\A#<CZTop::Message:.*>\z/, s
      end
      it "contains native address" do
        assert_match /:0x[[:xdigit:]]+\b/, s
      end
      it "contains number of frames" do
        assert_match /\bframes=0\b/, s
      end
      it "contains content size" do
        assert_match /\bcontent_size=0\b/, s
      end
      it "contains empty content description" do
        assert_match /\bcontent=\[\]/, s
      end
    end

    context "with content" do
      before(:each) { msg << "FOO" << "BAR" }
      it "contains number of frames" do
        assert_match /\bframes=2\b/, s
      end
      it "contains content size" do
        assert_match /\bcontent_size=6\b/, s
      end
      it "contains content description" do
        assert_match /\bcontent=\[.+\]/, s
      end
    end

    context "with huge message" do
      before(:each) { msg << "FOO" * 1000 } # 3000 byte message
      it "contains content placeholder" do
        assert_match /\bcontent=\[\.\.\.\]/, s
      end
    end
  end

  describe "#[]" do
    context "with existing frame" do
      subject { CZTop::Message.new %w[ foo ] }
      Then { "foo" == subject[0] }
    end

    context "with non-existing frame" do
      subject { CZTop::Message.new %w[ foo ] }
      Then { subject[1].nil? }
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
