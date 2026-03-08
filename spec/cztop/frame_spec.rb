# frozen_string_literal: true

require_relative 'spec_helper'

describe CZTop::Frame do
  include HasFFIDelegateExamples
  include ZMQHelper


  describe '.send_to' do
    let(:frame) { CZTop::Frame.new }
    let(:socket) { Object.new }

    it 'delegates it to CZMQ::FFI' do
      CZMQ::FFI::Zframe.stub(:send, 0) do
        frame.send_to(socket)
      end
    end


    describe 'with MORE option set' do
      it 'provides correct flags' do
        provided_flags = nil
        CZMQ::FFI::Zframe.stub(:send, ->(zframe, sock, flags) { provided_flags = flags; 0 }) do
          frame.send_to(socket, more: true)
        end
        assert_operator CZTop::Frame::FLAG_MORE & provided_flags, :>, 0
      end
    end


    describe 'with DONTWAIT set' do
      it 'provides correct flags' do
        provided_flags = nil
        CZMQ::FFI::Zframe.stub(:send, ->(zframe, sock, flags) { provided_flags = flags; 0 }) do
          frame.send_to(socket, dontwait: true)
        end
        assert_operator CZTop::Frame::FLAG_DONTWAIT & provided_flags, :>, 0
      end


      describe "when it can't send right now" do
        let(:socket) { CZTop::Socket.new_by_type(:DEALER) }

        it 'raises' do
          assert_raises(IO::EAGAINWaitWritable) do
            frame.send_to(socket, dontwait: true)
          end
        end
      end
    end


    describe 'with a surviving zframe_t' do
      let(:current_delegate) { frame.ffi_delegate }
      let(:old_delegate) { frame.ffi_delegate }
      before { old_delegate } # eagerly evaluate


      describe 'with REUSE option set' do
        it 'provides correct flags' do
          provided_flags = nil
          CZMQ::FFI::Zframe.stub(:send, ->(zframe, sock, flags) {
            provided_flags = flags
            zframe.__ptr_give_ref
            0
          }) do
            frame.send_to(socket, reuse: true)
          end
          assert_operator CZTop::Frame::FLAG_REUSE & provided_flags, :>, 0
        end

        it 'wraps native counterpart in new Zframe' do
          CZMQ::FFI::Zframe.stub(:send, ->(zframe, sock, flags) {
            zframe.__ptr_give_ref
            0
          }) do
            frame.send_to(socket, reuse: true)
          end
          refute_same old_delegate, current_delegate
        end
      end


      describe "when there's an error" do
        it 'wraps native counterpart in new Zframe' do
          CZMQ::FFI::Zframe.stub(:send, ->(zframe, sock, flags) {
            zframe.__ptr_give_ref
            -1
          }) do
            frame.send_to(socket) rescue nil
          end
          refute_same old_delegate, current_delegate
        end

        it 'raises' do
          CZMQ::FFI::Zframe.stub(:send, ->(zframe, sock, flags) {
            zframe.__ptr_give_ref
            -1
          }) do
            assert_raises(SystemCallError) { frame.send_to(socket) }
          end
        end
      end
    end
  end


  describe '.receive_from' do
    let(:source) { Object.new }
    let(:frame_delegate) { CZTop::Frame.new.ffi_delegate }

    it 'receives frame from source' do
      CZMQ::FFI::Zframe.stub(:recv, ->(src) { frame_delegate }) do
        assert_equal frame_delegate, CZTop::Frame.receive_from(source).ffi_delegate
      end
    end
  end


  describe '#initialize' do
    describe 'given content' do
      let(:content) { 'foobar' }
      let(:frame) { CZTop::Frame.new content }

      it 'initializes frame with content' do
        assert_equal content, frame.content
      end
    end


    describe 'given no content' do
      let(:frame) { CZTop::Frame.new }

      it 'initializes empty frame' do
        assert_empty frame
      end

      it 'has empty string as content' do
        assert_equal '', frame.content
      end
    end
  end


  describe '#size' do
    let(:content) { 'foobar' }
    let(:frame) { CZTop::Frame.new(content) }

    it { assert_equal content.bytesize, frame.size }
  end


  describe '#empty' do
    describe 'given empty frame' do
      let(:frame) { CZTop::Frame.new }

      it 'returns true' do
        assert_operator frame, :empty?
      end
    end


    describe 'given non-empty frame' do
      let(:frame) { CZTop::Frame.new('foo') }

      it 'returns false' do
        refute_operator frame, :empty?
      end
    end
  end


  describe '#content' do
    let(:content) { 'foobar' }
    let(:frame) { CZTop::Frame.new(content) }

    it 'returns its content as a String' do
      assert_equal content, frame.content
    end

    it 'has alias #to_s' do
      assert_equal content, frame.to_s
    end

    it 'returns content as binary string' do
      assert_equal Encoding::BINARY, frame.to_s.encoding
    end
  end


  describe '#content=' do
    let(:frame) { CZTop::Frame.new }


    describe 'with text content' do
      let(:content) { 'foobar' }
      before { frame.content = content }

      it { assert_equal content, frame.content }
      it { assert_equal content.bytesize, frame.size }
    end


    describe 'with binary content' do
      let(:content) { (+'foobar').encode!(Encoding::BINARY) }
      before { frame.content = content }

      it { assert_equal content, frame.content }
      it { assert_equal content.bytesize, frame.size }
    end
  end


  describe '#dup' do
    describe 'given frame and its duplicate' do
      let(:frame) { CZTop::Frame.new('foo') }
      let(:duplicate_frame) { frame.dup }

      it { assert_equal frame, duplicate_frame }
      it { assert_equal frame.content, duplicate_frame.content }
      it { refute_same frame, duplicate_frame }
    end
  end


  describe '#more?' do
    let(:frame) { CZTop::Frame.new }


    describe 'given Frame with MORE indicator set' do
      before { frame.more = true }

      it { assert frame.more? }
    end


    describe 'given Frame with MORE indicator NOT set' do
      before { frame.more = false }

      it { refute frame.more? }
    end
  end


  describe '#more=' do
    let(:frame) { CZTop::Frame.new }

    it { refute frame.more? }

    describe 'when setting to true' do
      before { frame.more = true }

      it { assert frame.more? }
    end


    describe 'when setting to false' do
      before { frame.more = false }

      it { refute frame.more? }
    end
  end


  describe '#==' do
    let(:frame) { CZTop::Frame.new('foo') }


    describe 'given identical other frame' do
      let(:other_frame) { CZTop::Frame.new('foo') }

      it 'is equal' do
        assert_operator frame, :==, other_frame
        assert_operator other_frame, :==, frame
      end


      describe 'given other frame has MORE flag set' do
        let(:other_frame) { f = CZTop::Frame.new('foo'); f.more = true; f }

        it 'is still equal' do
          assert_operator frame, :==, other_frame
        end
      end
    end


    describe 'given different other frame' do
      let(:other_frame) { CZTop::Frame.new('bar') }

      it 'is not equal' do
        refute_operator frame, :==, other_frame
        refute_operator other_frame, :==, frame
      end
    end
  end


  describe '#routing_id' do
    before { skip "requires CZMQ drafts" unless has_czmq_drafts? }
    let(:frame) { CZTop::Frame.new }


    describe 'with no routing ID set' do
      it { assert_equal 0, frame.routing_id }
    end


    describe 'with routing ID set' do
      let(:new_routing_id) { 123_456 }
      before { frame.routing_id = new_routing_id }

      it { assert_equal new_routing_id, frame.routing_id }
    end
  end


  describe '#routing_id=' do
    before { skip "requires CZMQ drafts" unless has_czmq_drafts? }
    let(:frame) { CZTop::Frame.new }


    describe 'with valid routing ID' do
      let(:new_routing_id) { 123_456 }
      before { frame.routing_id = new_routing_id }

      it { assert_equal new_routing_id, frame.routing_id }
    end


    describe 'with negative routing ID' do
      it { assert_raises(RangeError) { frame.routing_id = -123_456 } }
    end


    describe 'with too big routing ID' do
      it { assert_raises(RangeError) { frame.routing_id = 123_456_345_676_543_456_765 } }
    end
  end


  describe '#group' do
    before { skip "requires CZMQ drafts" unless has_czmq_drafts? }
    let(:frame) { CZTop::Frame.new }


    describe 'with no group set' do
      it { assert_nil frame.group }
    end


    describe 'with empty group set' do
      it 'returns nil' do
        frame.ffi_delegate.define_singleton_method(:group) { '' }
        assert_nil frame.group
      end
    end


    describe 'with group set' do
      let(:new_group) { 'group1' }
      before { frame.group = new_group }

      it { assert_equal new_group, frame.group }
    end
  end


  describe '#group=' do
    before { skip "requires CZMQ drafts" unless has_czmq_drafts? }
    let(:frame) { CZTop::Frame.new }


    describe 'with valid group' do
      let(:new_group) { 'group1' }
      before { frame.group = new_group }

      it { assert_equal new_group, frame.group }
    end


    describe 'with too long group' do
      it { assert_raises(ArgumentError) { frame.group = 'x' * 256 } }
    end
  end
end
