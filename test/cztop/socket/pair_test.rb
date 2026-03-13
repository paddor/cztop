# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::PAIR do
  describe 'integration' do
    i = 0
    let(:endpoint) { "inproc://pair_test_#{i += 1}" }


    describe 'with @ and > prefix convention' do
      let(:binder)    { CZTop::Socket::PAIR.new("@#{endpoint}") }
      let(:connector) { CZTop::Socket::PAIR.new(">#{endpoint}") }

      before do
        binder.options.sndtimeo = 100
        binder.options.rcvtimeo = 100
        connector.options.sndtimeo = 100
        connector.options.rcvtimeo = 100
      end


      it 'creates a pair using @ for bind and > for connect' do
        binder
        connector
      end


      it 'sends messages bidirectionally' do
        binder
        connector

        binder << 'from_binder'
        msg = connector.receive
        assert_equal ['from_binder'], msg

        connector << 'from_connector'
        msg = binder.receive
        assert_equal ['from_connector'], msg
      end
    end


    describe 'with explicit bind/connect' do
      let(:pair_a) { CZTop::Socket::PAIR.new }
      let(:pair_b) { CZTop::Socket::PAIR.new }

      before do
        pair_a.options.sndtimeo = 100
        pair_a.options.rcvtimeo = 100
        pair_b.options.sndtimeo = 100
        pair_b.options.rcvtimeo = 100

        pair_a.bind endpoint
        pair_b.connect endpoint
      end


      it 'sends and receives in both directions' do
        pair_a << 'hello'
        msg = pair_b.receive
        assert_equal ['hello'], msg

        pair_b << 'world'
        msg = pair_a.receive
        assert_equal ['world'], msg
      end


      it 'handles multipart messages bidirectionally' do
        pair_a << %w[multi part]
        msg = pair_b.receive
        assert_equal %w[multi part], msg

        pair_b << %w[reply parts here]
        msg = pair_a.receive
        assert_equal %w[reply parts here], msg
      end


      it 'sends multiple sequential messages' do
        5.times do |n|
          pair_a << "a_to_b_#{n}"
          msg = pair_b.receive
          assert_equal ["a_to_b_#{n}"], msg

          pair_b << "b_to_a_#{n}"
          msg = pair_a.receive
          assert_equal ["b_to_a_#{n}"], msg
        end
      end
    end
  end
end
