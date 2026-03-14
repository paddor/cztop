#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'
require 'async'

# ZGuide Chapter 4 — Heartbeat Pattern
# PUB/SUB liveness detection: the publisher sends periodic heartbeats.
# The subscriber monitors them and detects alive → dead → recovered
# transitions when the publisher pauses and resumes.
#
# Publisher runs in a thread. Monitor/subscriber runs inside Sync { }.

describe 'Heartbeat' do
  it 'detects alive, dead, and recovered states' do
    endpoint = 'inproc://zg05_heartbeat'
    heartbeat_ivl = 0.05  # 50ms between heartbeats
    dead_threshold = heartbeat_ivl * 3
    events = []

    publisher = Thread.new do
      pub = Cztop::Socket::PUB.bind(endpoint)
      sleep 0.02

      # Phase 1: alive
      8.times do
        pub << 'HEARTBEAT'
        sleep heartbeat_ivl
      end

      # Phase 2: simulate failure (stop sending)
      sleep dead_threshold * 2

      # Phase 3: recover
      8.times do
        pub << 'HEARTBEAT'
        sleep heartbeat_ivl
      end
    end

    Sync do
      sub = Cztop::Socket::SUB.connect(endpoint, prefix: 'HEARTBEAT')
      sub.recv_timeout = dead_threshold
      alive = false

      20.times do
        begin
          sub.receive
          unless alive
            events << :alive
            alive = true
            puts "  monitor: ALIVE"
          end
        rescue IO::TimeoutError
          if alive
            events << :dead
            alive = false
            puts "  monitor: DEAD"
          end
        end
      end
    end

    publisher.join

    puts "  events: #{events.inspect}"
    assert_includes events, :alive, 'expected to detect alive state'
    assert_includes events, :dead, 'expected to detect dead state'

    alive_indices = events.each_index.select { |i| events[i] == :alive }
    dead_indices  = events.each_index.select { |i| events[i] == :dead }
    assert(alive_indices.last > dead_indices.first, 'expected recovery after death')
  end
end
