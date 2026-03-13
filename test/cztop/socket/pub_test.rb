# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::PUB do
  describe 'integration' do
    let(:pub) { CZTop::Socket::PUB.new }
    i = 0
    let(:endpoint) { "inproc://pub_test_#{i += 1}" }

    before do
      pub.options.sndtimeo = 100
      pub.bind endpoint
    end


    it 'publishes messages to a subscribed SUB' do
      sub = CZTop::Socket::SUB.new
      sub.options.rcvtimeo = 100
      sub.subscribe
      sub.connect endpoint
      sleep 0.05

      pub << 'broadcast'
      msg = sub.receive
      assert_equal ['broadcast'], msg
    end


    it 'publishes with topic prefix filtering' do
      sub = CZTop::Socket::SUB.new
      sub.options.rcvtimeo = 100
      sub.subscribe('weather')
      sub.connect endpoint
      sleep 0.05

      pub << 'weather.nyc 72F'
      msg = sub.receive
      assert_equal ['weather.nyc 72F'], msg
    end


    it 'does not deliver messages to non-matching subscriptions' do
      sub = CZTop::Socket::SUB.new
      sub.options.rcvtimeo = 50
      sub.subscribe('sports')
      sub.connect endpoint
      sleep 0.05

      pub << 'weather.nyc 72F'
      assert_raises(IO::EAGAINWaitReadable, IO::TimeoutError) { sub.receive }
    end


    it 'publishes multipart messages' do
      sub = CZTop::Socket::SUB.new
      sub.options.rcvtimeo = 100
      sub.subscribe
      sub.connect endpoint
      sleep 0.05

      pub << %w[topic payload data]
      msg = sub.receive
      assert_equal %w[topic payload data], msg
    end


    it 'fans out to multiple subscribers' do
      subs = 3.times.map do
        CZTop::Socket::SUB.new.tap do |s|
          s.options.rcvtimeo = 100
          s.subscribe
          s.connect endpoint
        end
      end
      sleep 0.05

      pub << 'fanout'
      subs.each do |sub|
        msg = sub.receive
        assert_equal ['fanout'], msg
      end
    end
  end
end
