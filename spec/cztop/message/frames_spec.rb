# frozen_string_literal: true

require_relative '../../spec_helper'

describe CZTop::Message do
  subject { CZTop::Message.new }
  context 'empty message' do
    describe '#size' do
      it 'return zero' do
        assert_equal 0, subject.size
      end
    end
  end
  describe '#frames' do
    let(:frames) { subject.frames }
    it 'returns FramesAccessor' do
      assert_kind_of CZTop::Message::FramesAccessor, frames
    end
  end
end

describe CZTop::Message::FramesAccessor do
  it 'is enumerable' do
    assert_operator described_class, :<, Enumerable
  end

  let(:frames) { msg.frames }
  let(:msg) { CZTop::Message.new(frame_contents) }

  context 'message with content' do
    let(:frame_contents) { %w[foo bar baz] }

    describe '#first' do
      it 'returns first frame' do
        assert_equal 'foo', frames.first.to_s
      end
    end

    describe '#last' do
      it 'returns last frame' do
        assert_equal 'baz', frames.last.to_s
      end
    end
    describe '#[]' do
      it 'returns correct frame' do
        assert_equal frames.to_a[0], frames[0]
        assert_equal frames.to_a[1], frames[1]
        assert_equal frames.to_a[2], frames[2]
        assert_equal frames.to_a[-1], frames[-1]
        assert_nil frames[99]
      end
    end
    describe '#each' do
      it 'yields frames' do
        frames.each { |frame| assert_kind_of CZTop::Frame, frame }
      end
      it 'yields all frames' do
        assert_equal frame_contents, frames.to_a.map(&:to_s)
      end
    end
  end

  context 'message with no content' do
    let(:frame_contents) { [] }
    describe '#first' do
      it 'returns nil' do
        assert_nil frames.first
      end
    end

    describe '#last' do
      it 'returns nil' do
        assert_nil frames.last
      end
    end
    describe '#[]' do
      it 'returns nil' do
        assert_nil frames[0]
        assert_nil frames[1]
        assert_nil frames[2]
        assert_nil frames[-1]
        assert_nil frames[99]
      end
    end
    describe '#each' do
      it "doesn't yield" do
        frames.each { flunk }
      end
    end
  end
end
