# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::PULL do
  describe 'integration' do
    i = 0
    let(:endpoint) { "inproc://pull_test_#{i += 1}" }

    let(:pull) do
      CZTop::Socket::PULL.new.tap do |s|
        s.recv_timeout = 0.1
        s.bind endpoint
      end
    end


    it 'receives from a single PUSH' do
      pull

      push = CZTop::Socket::PUSH.new
      push.send_timeout = 0.1
      push.connect endpoint

      push << 'single'
      msg = pull.receive
      assert_equal ['single'], msg
    end


    it 'receives fan-in from multiple PUSH sockets' do
      pull

      pushers = 3.times.map do
        CZTop::Socket::PUSH.new.tap do |p|
          p.send_timeout = 0.1
          p.connect endpoint
        end
      end

      pushers.each_with_index { |p, n| p << "from_push_#{n}" }

      received = []
      3.times { received << pull.receive.first }

      assert_equal 3, received.size
      3.times { |n| assert_includes received, "from_push_#{n}" }
    end


    it 'receives multipart messages from fan-in' do
      pull

      push_a = CZTop::Socket::PUSH.new
      push_a.send_timeout = 0.1
      push_a.connect endpoint

      push_b = CZTop::Socket::PUSH.new
      push_b.send_timeout = 0.1
      push_b.connect endpoint

      push_a << %w[source_a data_a]
      push_b << %w[source_b data_b]

      received = []
      2.times { received << pull.receive }

      sources = received.map(&:first).sort
      assert_equal %w[source_a source_b], sources
    end


    it 'receives many messages from many pushers' do
      pull

      pushers = 5.times.map do
        CZTop::Socket::PUSH.new.tap do |p|
          p.send_timeout = 0.1
          p.connect endpoint
        end
      end

      pushers.each_with_index do |p, n|
        2.times { |m| p << "pusher_#{n}_msg_#{m}" }
      end

      received = []
      10.times { received << pull.receive.first }

      assert_equal 10, received.size
      5.times do |n|
        2.times do |m|
          assert_includes received, "pusher_#{n}_msg_#{m}"
        end
      end
    end
  end
end
