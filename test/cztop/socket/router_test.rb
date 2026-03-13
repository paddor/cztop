# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::ROUTER do
  describe 'integration' do
    i = 0
    let(:endpoint) { "inproc://router_test_#{i += 1}" }

    let(:router) do
      CZTop::Socket::ROUTER.new.tap do |r|
        r.options.sndtimeo = 100
        r.options.rcvtimeo = 100
        r.bind endpoint
      end
    end


    describe '#send_to' do
      let(:identity) { 'test_dealer' }

      let(:dealer) do
        CZTop::Socket::DEALER.new.tap do |d|
          d.options.identity = identity
          d.options.sndtimeo = 100
          d.options.rcvtimeo = 100
          d.connect endpoint
        end
      end

      before do
        router
        dealer
        sleep 0.05
      end


      it 'routes a message to a specific identity' do
        dealer << %w[ping]
        msg = router.receive
        assert_equal identity, msg.first

        router.send_to(identity, 'pong')
        reply = dealer.receive
        assert_equal ['', 'pong'], reply
      end


      it 'routes multipart messages via send_to' do
        dealer << %w[hello]
        router.receive

        router.send_to(identity, %w[multi part])
        reply = dealer.receive
        assert_equal ['', 'multi', 'part'], reply
      end
    end


    describe 'routing between multiple dealers' do
      let(:id_a) { 'dealer_a' }
      let(:id_b) { 'dealer_b' }

      let(:dealer_a) do
        CZTop::Socket::DEALER.new.tap do |d|
          d.options.identity = id_a
          d.options.sndtimeo = 100
          d.options.rcvtimeo = 100
          d.connect endpoint
        end
      end

      let(:dealer_b) do
        CZTop::Socket::DEALER.new.tap do |d|
          d.options.identity = id_b
          d.options.sndtimeo = 100
          d.options.rcvtimeo = 100
          d.connect endpoint
        end
      end

      before do
        router
        dealer_a
        dealer_b
        sleep 0.05
      end


      it 'routes replies to correct dealers' do
        dealer_a << %w[from_a]
        dealer_b << %w[from_b]

        msgs = {}
        2.times do
          msg = router.receive
          identity = msg.first
          msgs[identity] = msg.last
        end

        assert_equal 'from_a', msgs[id_a]
        assert_equal 'from_b', msgs[id_b]

        router.send_to(id_a, 'reply_a')
        router.send_to(id_b, 'reply_b')

        reply_a = dealer_a.receive
        assert_equal 'reply_a', reply_a.last

        reply_b = dealer_b.receive
        assert_equal 'reply_b', reply_b.last
      end
    end
  end
end
