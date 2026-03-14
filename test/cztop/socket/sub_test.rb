# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::SUB do
  describe 'integration' do
    let(:pub) { CZTop::Socket::PUB.new }
    i = 0
    let(:endpoint) { "inproc://sub_test_#{i += 1}" }

    before do
      pub.send_timeout = 0.1
      pub.bind endpoint
    end


    it 'receives messages matching subscription' do
      sub = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub.recv_timeout = 0.1
      sub.subscribe('test')
      sub.connect endpoint
      sleep 0.05

      pub << 'test message'
      msg = sub.receive
      assert_equal ['test message'], msg
    end


    it 'subscribes to everything with empty prefix' do
      sub = CZTop::Socket::SUB.new
      sub.recv_timeout = 0.1
      sub.subscribe
      sub.connect endpoint
      sleep 0.05

      pub << 'anything goes'
      msg = sub.receive
      assert_equal ['anything goes'], msg
    end


    it 'filters by topic prefix' do
      sub = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub.recv_timeout = 0.05
      sub.subscribe('alpha')
      sub.connect endpoint
      sleep 0.05

      pub << 'beta should not arrive'
      assert_raises(IO::EAGAINWaitReadable, IO::TimeoutError) { sub.receive }

      pub << 'alpha should arrive'
      msg = sub.receive
      assert_equal ['alpha should arrive'], msg
    end


    it 'supports multiple subscriptions' do
      sub = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub.recv_timeout = 0.1
      sub.subscribe('cat')
      sub.subscribe('dog')
      sub.connect endpoint
      sleep 0.05

      pub << 'cat meows'
      msg = sub.receive
      assert_equal ['cat meows'], msg

      pub << 'dog barks'
      msg = sub.receive
      assert_equal ['dog barks'], msg
    end


    it 'unsubscribes from a topic' do
      sub = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub.recv_timeout = 0.05
      sub.subscribe('temp')
      sub.connect endpoint
      sleep 0.05

      pub << 'temp data'
      msg = sub.receive
      assert_equal ['temp data'], msg

      sub.unsubscribe('temp')
      sleep 0.05

      pub << 'temp data again'
      assert_raises(IO::EAGAINWaitReadable, IO::TimeoutError) { sub.receive }
    end


    it 'can be initialized with a subscription' do
      sub = CZTop::Socket::SUB.new(nil, prefix: 'init_topic')
      sub.recv_timeout = 0.1
      sub.connect endpoint
      sleep 0.05

      pub << 'init_topic hello'
      msg = sub.receive
      assert_equal ['init_topic hello'], msg
    end
  end
end
