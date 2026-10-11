# frozen_string_literal: true

require_relative '../test_helper'

class CZTopSocketROUTERTest < Minitest::Spec
  describe 'integration' do
    def endpoint
      @endpoint ||= "inproc://router_test_#{SecureRandom.hex(8)}"
    end

    def router
      @router ||= CZTop::Socket::ROUTER.new.tap do |r|
        r.send_timeout = 0.1
        r.recv_timeout = 0.1
        r.bind endpoint
      end
    end


    describe '#send_to' do
      def identity
        @identity ||= 'test_dealer'
      end

      def dealer
        @dealer ||= CZTop::Socket::DEALER.new.tap do |d|
          d.identity = identity
          d.send_timeout = 0.1
          d.recv_timeout = 0.1
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
      def id_a
        @id_a ||= 'dealer_a'
      end

      def id_b
        @id_b ||= 'dealer_b'
      end

      def dealer_a
        @dealer_a ||= CZTop::Socket::DEALER.new.tap do |d|
          d.identity = id_a
          d.send_timeout = 0.1
          d.recv_timeout = 0.1
          d.connect endpoint
        end
      end

      def dealer_b
        @dealer_b ||= CZTop::Socket::DEALER.new.tap do |d|
          d.identity = id_b
          d.send_timeout = 0.1
          d.recv_timeout = 0.1
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
