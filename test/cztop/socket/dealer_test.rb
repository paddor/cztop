# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::DEALER do
  describe 'integration' do
    let(:dealer) { CZTop::Socket::DEALER.new }
    let(:router) { CZTop::Socket::ROUTER.new }
    i = 0
    let(:endpoint) { "inproc://dealer_test_#{i += 1}" }

    before do
      dealer.send_timeout = 0.1
      dealer.recv_timeout = 0.1
      router.send_timeout = 0.1
      router.recv_timeout = 0.1

      router.bind endpoint
      dealer.connect endpoint
    end


    it 'sends asynchronous messages to ROUTER' do
      dealer << %w[hello]
      msg = router.receive
      # ROUTER prepends identity frame
      assert_operator msg.size, :>=, 2
      identity = msg.first
      refute_empty identity
      # payload follows: empty delimiter + content
      assert_equal 'hello', msg.last
    end


    it 'receives replies from ROUTER' do
      dealer << %w[request]
      msg = router.receive
      identity = msg.first

      router << [identity, '', 'response']
      reply = dealer.receive
      assert_equal ['', 'response'], reply
    end


    it 'sends multiple messages without waiting for replies' do
      3.times { |n| dealer << ["msg_#{n}"] }

      3.times do |n|
        msg = router.receive
        assert_equal "msg_#{n}", msg.last
      end
    end


    it 'sets and uses a custom identity' do
      custom_id = 'my_dealer_id'
      d = CZTop::Socket::DEALER.new
      d.identity = custom_id
      d.send_timeout = 0.1
      d.recv_timeout = 0.1

      r = CZTop::Socket::ROUTER.new
      r.send_timeout = 0.1
      r.recv_timeout = 0.1

      ep = "inproc://dealer_test_identity_#{i += 1}"
      r.bind ep
      d.connect ep

      d << %w[identify_me]
      msg = r.receive
      assert_equal custom_id, msg.first
    end
  end
end
