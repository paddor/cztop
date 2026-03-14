# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::XPUB do
  describe 'integration' do
    i = 0
    let(:endpoint) { "inproc://xpub_test_#{i += 1}" }

    let(:xpub) do
      CZTop::Socket::XPUB.new.tap do |s|
        s.send_timeout = 0.1
        s.recv_timeout = 0.1
        s.bind endpoint
      end
    end


    it 'receives subscription messages from SUB' do
      xpub

      sub = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub.recv_timeout = 0.1
      sub.subscribe('news')
      sub.connect endpoint

      # XPUB receives subscription events: \x01 + topic
      msg = xpub.receive
      assert_equal 1, msg.size
      assert_equal "\x01news", msg.first
    end


    it 'forwards published data to subscribers' do
      xpub

      sub = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub.recv_timeout = 0.1
      sub.subscribe('data')
      sub.connect endpoint

      # Consume subscription event
      xpub.receive

      xpub << 'data payload'
      msg = sub.receive
      assert_equal ['data payload'], msg
    end


    it 'receives unsubscribe events' do
      xpub

      sub = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub.recv_timeout = 0.1
      sub.subscribe('topic')
      sub.connect endpoint

      # Consume subscribe event
      event = xpub.receive
      assert_equal "\x01topic", event.first

      sub.unsubscribe('topic')
      event = xpub.receive
      assert_equal "\x00topic", event.first
    end


    it 'acts as proxy between PUB and SUB via XSUB' do
      xsub = CZTop::Socket::XSUB.new
      xsub.send_timeout = 0.1
      xsub.recv_timeout = 0.1

      pub_ep = "inproc://xpub_proxy_pub_#{i += 1}"
      sub_ep = "inproc://xpub_proxy_sub_#{i}"

      xpub_proxy = CZTop::Socket::XPUB.new
      xpub_proxy.send_timeout = 0.1
      xpub_proxy.recv_timeout = 0.1
      xpub_proxy.bind sub_ep

      pub = CZTop::Socket::PUB.new
      pub.send_timeout = 0.1
      pub.bind pub_ep

      xsub.connect pub_ep

      sub = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub.recv_timeout = 0.1
      sub.subscribe('proxy')
      sub.connect sub_ep

      # Get subscription from SUB side
      sub_event = xpub_proxy.receive
      # Forward subscription to XSUB (which forwards to PUB)
      xsub << sub_event.first
      sleep 0.05

      pub << 'proxy hello'

      # Read from XSUB, forward to XPUB
      msg = xsub.receive
      xpub_proxy << msg

      result = sub.receive
      assert_equal ['proxy hello'], result
    end
  end
end
