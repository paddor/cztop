# frozen_string_literal: true

require_relative 'spec_helper'

describe CZTop::Message do
  include HasFFIDelegateExamples
  include ZMQHelper

  let(:msg)          { CZTop::Message.new }
  let(:ffi_delegate) { msg.ffi_delegate }
  let(:subject)      { CZTop::Message.new }


  describe '#initialize' do
    describe 'with initial string' do
      let(:content) { 'foo' }
      let(:subject) { CZTop::Message.new(content) }

      it 'sets content' do
        assert_equal content, subject.frames.first.to_s
      end

      it 'has one frame' do
        assert_equal 1, subject.frames.count
      end
    end


    describe 'with array of strings' do
      let(:parts) { ['foo', '', 'bar'] }
      let(:msg) { CZTop::Message.new(parts) }

      it 'takes them as frames' do
        assert_equal parts.size, msg.size
        assert_equal parts, msg.frames.map(&:to_s)
      end
    end


    describe 'with empty part' do
      let(:parts) { [''] }
      let(:msg) { CZTop::Message.new(parts) }

      it 'works' do
        assert_equal parts.size, msg.size
        assert_equal parts, msg.frames.map(&:to_s)
        assert_equal 0, msg.content_size
      end
    end


    describe 'with empty array' do
      let(:parts) { [] }
      let(:msg) { CZTop::Message.new(parts) }

      it 'works' do
        msg
      end
    end
  end


  describe '.coerce' do
    describe 'with a Message' do
      it 'takes the Message as is' do
        assert_same msg, CZTop::Message.coerce(msg)
      end
    end


    describe 'with a String' do
      let(:content) { 'foobar' }
      let(:coerced_msg) { CZTop::Message.coerce(content) }

      it 'creates a new Message from the String' do
        assert_kind_of CZTop::Message, coerced_msg
        assert_equal 1, coerced_msg.size
        assert_equal content, coerced_msg.frames.first.to_s
      end
    end


    describe 'with a Frame' do
      let(:frame_content) { 'foobar special content' }
      let(:frame) { CZTop::Frame.new(frame_content) }

      it 'creates a Message from the Frame' do
        coerced_msg = CZTop::Message.coerce(frame)
        assert_kind_of CZTop::Message, coerced_msg
        assert_equal 1, coerced_msg.size
        assert_equal frame_content, coerced_msg.frames.first.to_s
      end
    end


    describe 'with array of strings' do
      let(:parts) { ['foo', '', 'bar'] }
      let(:coerced_msg) { CZTop::Message.coerce(parts) }

      it 'takes them as frames' do
        assert_equal parts.size, coerced_msg.size
        assert_equal parts, coerced_msg.frames.map(&:to_s)
      end
    end


    describe 'given something else' do
      it 'raises' do
        assert_raises(ArgumentError) { CZTop::Message.coerce(Object.new) }
      end
    end
  end


  describe '#<<' do
    let(:msg) { CZTop::Message.new 'foo' }

    it 'starts with one frame' do
      assert_equal 1, msg.size
    end


    describe 'with a string' do
      it 'appends the string as a frame' do
        msg << 'bar'
        assert_equal 2, msg.size
        assert_equal %w[foo bar], msg.to_a
      end


      describe 'when this fails' do
        it 'raises' do
          ffi_delegate.define_singleton_method(:addmem) { |*| -1 }
          CZMQ::FFI::Errors.stub(:errno, Errno::EPERM::Errno) do
            assert_raises(Errno::EPERM) { msg << 'bar' }
          end
        end
      end
    end


    describe 'with binary data' do
      let(:frame) { "foo\x08\0\0bar\0\0\0\x11" } # contains NULL bytes

      it 'appends the binary data' do
        msg << frame
        assert_equal 2, msg.size
        assert_equal frame, msg[-1]
      end
    end


    describe 'with a frame' do
      it 'appends the frame' do
        frame = CZTop::Frame.new('bar')
        msg << frame
        assert_equal 2, msg.size
        assert_equal %w[foo bar], msg.to_a
      end


      describe 'when this fails' do
        it 'raises' do
          ffi_delegate.define_singleton_method(:append) { |*| -1 }
          CZMQ::FFI::Errors.stub(:errno, Errno::EPERM::Errno) do
            assert_raises(Errno::EPERM) { msg << CZTop::Frame.new('bar') }
          end
        end
      end
    end


    describe 'with something else' do
      it 'raises' do
        assert_raises(ArgumentError) { msg << Object.new }
      end
    end


    describe 'method chaining' do
      it 'supports chaining' do
        msg << 'FOO' << 'BAR'
        assert_equal %w[foo FOO BAR], msg.to_a
      end
    end
  end


  describe '#prepend' do
    let(:msg) { CZTop::Message.new 'foo' }

    it 'starts with one frame' do
      assert_equal 1, msg.size
    end


    describe 'with a string' do
      it 'prepends the string' do
        msg.prepend 'bar'
        assert_equal 2, msg.size
        assert_equal %w[bar foo], msg.to_a
      end
    end


    describe 'with binary data' do
      let(:frame) { "foo\0\0\0bar" } # contains NULL byte

      it 'prepends the binary data' do
        msg.prepend frame
        assert_equal 2, msg.size
        assert_equal frame, msg[0]
      end


      describe 'when this fails' do
        it 'raises' do
          ffi_delegate.define_singleton_method(:pushmem) { |*| -1 }
          CZMQ::FFI::Errors.stub(:errno, Errno::EPERM::Errno) do
            assert_raises(Errno::EPERM) { msg.prepend "foo\0\0\0bar" }
          end
        end
      end
    end


    describe 'with a frame' do
      it 'prepends the frame' do
        msg.prepend CZTop::Frame.new('bar')
        assert_equal 2, msg.size
        assert_equal %w[bar foo], msg.to_a
      end


      describe 'when this fails' do
        it 'raises' do
          ffi_delegate.define_singleton_method(:prepend) { |*| -1 }
          CZMQ::FFI::Errors.stub(:errno, Errno::EPERM::Errno) do
            assert_raises(Errno::EPERM) { msg.prepend CZTop::Frame.new('bar') }
          end
        end
      end
    end


    describe 'with something else' do
      it 'raises' do
        assert_raises(ArgumentError) { msg.prepend Object.new }
      end
    end
  end


  describe '#pop' do
    before { subject << 'FOO' << 'BAR' }

    it 'returns first part' do
      assert_equal 'FOO', subject.pop
    end

    it 'removes it from message' do
      subject.pop
      assert_equal %w[BAR], subject.to_a
    end
  end


  describe '#send_to' do
    let(:msg) { CZTop::Message.new 'foo' }


    describe 'with no frames' do
      let(:msg) { CZTop::Message.new }

      it 'fails' do
        assert_raises ArgumentError do
          msg.send_to(Object.new)
        end
      end
    end

    it 'waits for writability' do
      # NOTE: we raise because we don't want it to actually send
      dest = Object.new
      dest.define_singleton_method(:wait_writable) { raise IO::TimeoutError }

      assert_raises IO::TimeoutError do
        msg.send_to(dest)
      end
    end


    describe 'when successful' do
      it 'sends its delegate to the destination' do
        dest = Object.new
        dest.define_singleton_method(:wait_writable) { true }
        sent_args = nil
        CZMQ::FFI::Zmsg.stub(:send, ->(del, dst) { sent_args = [del, dst]; 0 }) do
          msg.send_to(dest)
        end
        assert_equal [ffi_delegate, dest], sent_args
      end
    end


    describe 'when NOT successful' do
      let(:dest) do
        obj = Object.new
        obj.define_singleton_method(:wait_writable) { true }
        obj
      end


      describe 'with sndtimeo reached' do
        it 'raises IO::EAGAINWaitWritable' do
          CZMQ::FFI::Zmsg.stub(:send, ->(*) { -1 }) do
            CZMQ::FFI::Errors.stub(:errno, Errno::EAGAIN::Errno) do
              assert_raises(IO::EAGAINWaitWritable) { msg.send_to(dest) }
            end
          end
        end
      end


      describe 'with host unreachable' do
        # NOTE: unroutable message given to ROUTER with ZMQ_ROUTER_MANDATORY
        # option set.
        it 'raises' do
          CZMQ::FFI::Zmsg.stub(:send, ->(*) { -1 }) do
            CZMQ::FFI::Errors.stub(:errno, Errno::EHOSTUNREACH::Errno) do
              assert_raises(SocketError) { msg.send_to(dest) }
            end
          end
        end
      end


      describe 'with other error' do
        it 'raises' do
          CZMQ::FFI::Zmsg.stub(:send, ->(*) { -1 }) do
            CZMQ::FFI::Errors.stub(:errno, Errno::EPERM::Errno) do
              assert_raises(Errno::EPERM) { msg.send_to(dest) }
            end
          end
        end
      end
    end
  end


  describe '.receive_from' do
    let(:src) do
      obj = Object.new
      obj.define_singleton_method(:wait_readable) { true }
      obj
    end

    it 'waits for readability' do
      # NOTE: we raise because we don't want it to actually receive
      src_obj = Object.new
      src_obj.define_singleton_method(:wait_readable) { raise IO::TimeoutError }

      assert_raises IO::TimeoutError do
        CZTop::Message.receive_from(src_obj)
      end
    end


    describe 'when successful' do
      it 'receives message from source' do
        ffi_del = CZMQ::FFI::Zmsg.new
        CZMQ::FFI::Zmsg.stub(:recv, ->(_s) { ffi_del }) do
          received = CZTop::Message.receive_from(src)
          assert_kind_of CZTop::Message, received
          assert_same ffi_del, received.ffi_delegate
        end
      end
    end


    describe 'when NOT successful' do
      let(:nullptr) { ::FFI::Pointer::NULL }


      describe 'when interrupted' do
        it 'raises Interrupt' do
          CZMQ::FFI.stub(:zmsg_recv, ->(_) { nullptr }) do
            CZMQ::FFI::Errors.stub(:errno, Errno::EINTR::Errno) do
              assert_raises(Interrupt) { CZTop::Message.receive_from(src) }
            end
          end
        end
      end


      describe 'with rcvtimeo reached' do
        it 'raises IO::EAGAINWaitReadable' do
          CZMQ::FFI.stub(:zmsg_recv, ->(_) { nullptr }) do
            CZMQ::FFI::Errors.stub(:errno, Errno::EAGAIN::Errno) do
              assert_raises(IO::EAGAINWaitReadable) { CZTop::Message.receive_from(src) }
            end
          end
        end
      end


      describe 'with other error' do
        it 'raises RuntimeError' do
          CZMQ::FFI.stub(:zmsg_recv, ->(_) { nullptr }) do
            CZMQ::FFI::Errors.stub(:errno, Errno::EPERM::Errno) do
              assert_raises(Errno::EPERM) { CZTop::Message.receive_from(src) }
            end
          end
        end
      end
    end
  end


  describe '#empty?' do
    describe 'with no content' do
      it 'is empty' do
        assert_operator subject, :empty?
      end
    end


    describe 'with content' do
      let(:subject) { CZTop::Message.new 'foo' }

      it 'is not empty' do
        refute_operator subject, :empty?
      end
    end


    describe 'with empty frame' do
      let(:subject) { CZTop::Message.new '' }

      it 'is empty' do
        assert_operator subject, :empty?
      end
    end


    describe 'with no frames' do
      let(:subject) { CZTop::Message.new }

      it 'is empty' do
        assert_operator subject, :empty?
      end
    end
  end


  describe '#content_size' do
    describe 'with no content' do
      it 'has content size zero' do
        assert_equal 0, subject.content_size
      end
    end


    describe 'with content' do
      let(:subject) { CZTop::Message.new 'foo' }

      it 'returns correct content size' do
        assert_equal 3, subject.content_size
      end
    end
  end


  describe '#to_a' do
    describe 'with no frames' do
      it 'returns empty array' do
        assert_equal [], subject.to_a
      end
    end


    describe 'with frames' do
      let(:parts) { %w[foo bar] }
      let(:subject) { CZTop::Message.new parts }

      it 'returns array of frame strings' do
        assert_equal parts, subject.to_a
      end
    end
  end


  describe '#inspect' do
    let(:s) { msg.inspect }


    describe 'with empty message' do
      it 'contains class name' do
        assert_match(/\A#<CZTop::Message:.*>\z/, s)
      end

      it 'contains native address' do
        assert_match(/:0x[[:xdigit:]]+\b/, s)
      end

      it 'contains number of frames' do
        assert_match(/\bframes=0\b/, s)
      end

      it 'contains content size' do
        assert_match(/\bcontent_size=0\b/, s)
      end

      it 'contains empty content description' do
        assert_match(/\bcontent=\[\]/, s)
      end
    end


    describe 'with content' do
      before { msg << 'FOO' << 'BAR' }

      it 'contains number of frames' do
        assert_match(/\bframes=2\b/, s)
      end

      it 'contains content size' do
        assert_match(/\bcontent_size=6\b/, s)
      end

      it 'contains content description' do
        assert_match(/\bcontent=\[.+\]/, s)
      end
    end


    describe 'with huge message' do
      before { msg << 'FOO' * 1000 } # 3000 byte message

      it 'contains content placeholder' do
        assert_match(/\bcontent=\[\.\.\.\]/, s)
      end
    end
  end


  describe '#[]' do
    describe 'with existing frame' do
      let(:subject) { CZTop::Message.new %w[foo] }

      it 'returns frame content' do
        assert_equal 'foo', subject[0]
      end
    end


    describe 'with non-existing frame' do
      let(:subject) { CZTop::Message.new %w[foo] }

      it 'returns nil' do
        assert_nil subject[1]
      end
    end
  end


  describe '#routing_id' do
    before { skip 'requires CZMQ drafts' unless has_czmq_drafts? }


    describe 'with no routing ID set' do
      it 'returns zero' do
        assert_equal 0, msg.routing_id
      end
    end


    describe 'with routing ID set' do
      let(:routing_id) { 12_345 }

      it 'returns the routing ID' do
        msg.routing_id = routing_id
        assert_equal routing_id, msg.routing_id
      end
    end
  end


  describe '#routing_id=' do
    before { skip 'requires CZMQ drafts' unless has_czmq_drafts? }


    describe 'with valid routing ID' do
      let(:new_routing_id) { 123_456 }

      it 'sets routing ID' do
        msg.routing_id = new_routing_id
        assert_equal new_routing_id, msg.routing_id
      end
    end


    describe 'with negative routing ID' do
      it 'raises' do
        assert_raises(RangeError) { msg.routing_id = -123_456 }
      end
    end


    describe 'with too big routing ID' do
      it 'raises' do
        assert_raises(RangeError) { msg.routing_id = 123_456_345_676_543_456_765 }
      end
    end


    describe 'with non-integer' do
      it 'raises' do
        assert_raises(ArgumentError) { msg.routing_id = 'foo' }
      end
    end
  end
end
