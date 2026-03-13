# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::DEALER do
  describe 'integration' do
    let(:dealer) { CZTop::Socket::DEALER.new }
    let(:router) { CZTop::Socket::ROUTER.new }
    i = 0
    let(:endpoint) { "inproc://dealer_test_#{i += 1}" }

    before do
      dealer.options.sndtimeo = 100
      dealer.options.rcvtimeo = 100
      router.options.sndtimeo = 100
      router.options.rcvtimeo = 100

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
      d.options.identity = custom_id
      d.options.sndtimeo = 100
      d.options.rcvtimeo = 100

      r = CZTop::Socket::ROUTER.new
      r.options.sndtimeo = 100
      r.options.rcvtimeo = 100

      ep = "inproc://dealer_test_identity_#{i += 1}"
      r.bind ep
      d.connect ep

      d << %w[identify_me]
      msg = r.receive
      assert_equal custom_id, msg.first
    end
  end
end
