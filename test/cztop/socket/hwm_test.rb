# frozen_string_literal: true

require_relative '../test_helper'


describe 'HWM mute state' do
  describe 'PUSH/PULL — blocks when HWM reached' do
    i = 0
    let(:endpoint) { "inproc://hwm_push_pull_#{i += 1}" }

    it 'blocks sender after HWM is reached' do
      push = CZTop::Socket::PUSH.new
      push.sndhwm = 1
      push.send_timeout = 0
      push.bind endpoint

      pull = CZTop::Socket::PULL.new
      pull.rcvhwm = 1
      pull.recv_timeout = 0.1
      pull.connect endpoint
      sleep 0.05

      sent = 0
      blocked = false
      10_000.times do |n|
        push << "msg_#{n}"
        sent += 1
      rescue IO::TimeoutError, IO::EAGAINWaitWritable
        blocked = true
        break
      end

      assert sent > 0, 'should accept at least one message'
      assert blocked, 'should block before sending all 10000 messages'
    end
  end


  describe 'PUB/SUB — drops when HWM reached' do
    i = 0
    let(:endpoint) { "inproc://hwm_pub_sub_#{i += 1}" }

    it 'drops messages beyond HWM capacity' do
      pub = CZTop::Socket::PUB.new
      pub.sndhwm = 5
      pub.send_timeout = 0.1
      pub.bind endpoint

      sub = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub.rcvhwm = 5
      sub.recv_timeout = 0.01
      sub.subscribe('')
      sub.connect endpoint
      sleep 0.05

      50.times { |n| pub << "msg_#{n}" }

      received = 0
      loop do
        sub.receive
        received += 1
      rescue IO::TimeoutError, IO::EAGAINWaitReadable
        break
      end

      assert received > 0, 'should receive some messages'
      assert received < 50, "should drop some messages (received #{received})"
    end
  end


  describe 'ROUTER with router_mandatory — errors on full peer' do
    i = 0
    let(:endpoint) { "inproc://hwm_router_mandatory_#{i += 1}" }

    it 'raises when peer HWM is reached' do
      router = CZTop::Socket::ROUTER.new
      router.router_mandatory = true
      router.sndhwm = 1
      router.send_timeout = 0
      router.bind endpoint

      dealer = CZTop::Socket::DEALER.new
      dealer.identity = 'target'
      dealer.recv_timeout = 0.1
      dealer.connect endpoint
      sleep 0.05

      errored = false
      10_000.times do |n|
        router.send(['target', '', "msg_#{n}"])
      rescue SocketError, IO::TimeoutError, IO::EAGAINWaitWritable
        errored = true
        break
      end

      assert errored, 'should error when peer HWM is reached'
    end
  end
end
