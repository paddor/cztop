# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::XSUB do
  describe 'integration' do
    i = 0
    let(:endpoint) { "inproc://xsub_test_#{i += 1}" }

    let(:pub) do
      CZTop::Socket::PUB.new.tap do |s|
        s.send_timeout = 0.1
        s.bind endpoint
      end
    end

    let(:xsub) do
      CZTop::Socket::XSUB.new.tap do |s|
        s.send_timeout = 0.1
        s.recv_timeout = 0.1
        s.connect endpoint
      end
    end


    it 'subscribes via wire protocol and receives messages' do
      pub
      xsub

      # XSUB subscribes by sending a frame: \x01 + topic
      xsub << "\x01data"
      sleep 0.05

      pub << 'data payload'
      msg = xsub.receive
      assert_equal ['data payload'], msg
    end


    it 'subscribes to everything' do
      pub
      xsub

      # Subscribe to all messages
      xsub << "\x01"
      sleep 0.05

      pub << 'anything'
      msg = xsub.receive
      assert_equal ['anything'], msg
    end


    it 'unsubscribes via wire protocol' do
      pub
      xsub

      xsub << "\x01unsub_topic"
      sleep 0.05

      pub << 'unsub_topic first'
      msg = xsub.receive
      assert_equal ['unsub_topic first'], msg

      # Unsubscribe: \x00 + topic
      xsub << "\x00unsub_topic"
      sleep 0.05

      pub << 'unsub_topic second'
      assert_raises(IO::EAGAINWaitReadable, IO::TimeoutError) { xsub.receive }
    end


    it 'filters by topic prefix' do
      pub
      xsub

      xsub << "\x01alpha"
      sleep 0.05

      pub << 'alpha match'
      msg = xsub.receive
      assert_equal ['alpha match'], msg

      pub << 'beta no match'
      assert_raises(IO::EAGAINWaitReadable, IO::TimeoutError) { xsub.receive }
    end
  end
end
