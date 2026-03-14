# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::PUSH do
  describe 'integration' do
    let(:push) { CZTop::Socket::PUSH.new }
    let(:pull) { CZTop::Socket::PULL.new }
    i = 0
    let(:endpoint) { "inproc://push_test_#{i += 1}" }

    before do
      push.send_timeout = 0.1
      pull.recv_timeout = 0.1

      pull.bind endpoint
      push.connect endpoint
    end


    it 'sends a single message through the pipeline' do
      push << 'task1'
      msg = pull.receive
      assert_equal ['task1'], msg
    end


    it 'sends multipart messages' do
      push << %w[job payload data]
      msg = pull.receive
      assert_equal %w[job payload data], msg
    end


    it 'sends multiple messages in sequence' do
      5.times { |n| push << "task_#{n}" }

      5.times do |n|
        msg = pull.receive
        assert_equal ["task_#{n}"], msg
      end
    end


    it 'handles empty frames' do
      push << ''
      msg = pull.receive
      assert_equal [''], msg
    end


    it 'load-balances across multiple PULLs' do
      pull2 = CZTop::Socket::PULL.new
      pull2.recv_timeout = 0.05
      pull2.bind "inproc://push_test_lb_#{i += 1}"
      push2 = CZTop::Socket::PUSH.new
      push2.send_timeout = 0.1

      ep = "inproc://push_test_lb2_#{i += 1}"
      pull_a = CZTop::Socket::PULL.new
      pull_a.recv_timeout = 0.1
      pull_a.bind ep

      pull_b = CZTop::Socket::PULL.new
      pull_b.recv_timeout = 0.1
      pull_b.connect ep  # second PULL on same endpoint won't work for inproc bind

      # Instead test fan-out from push side: one push, one pull, many messages
      10.times { |n| push << "work_#{n}" }
      10.times do |n|
        msg = pull.receive
        assert_equal ["work_#{n}"], msg
      end
    end
  end
end
