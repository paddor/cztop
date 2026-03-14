#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'

# ZGuide Chapter 5 — Last Value Cache
# A caching proxy sits between publishers and subscribers. It caches
# the latest value for each topic. When a new subscriber joins, it
# immediately receives the cached value (snapshot) before live updates.
# Uses REQ/REP for snapshot requests and PUB/SUB for live data.

describe 'Last Value Cache' do
  it 'serves cached values to late-joining subscribers' do
    pub_ep      = 'inproc://zg06_pub'
    sub_ep      = 'inproc://zg06_sub'
    snapshot_ep = 'inproc://zg06_snapshot'
    received_late = []

    cache = {}
    cache_mu = Mutex.new

    # Cache proxy: two threads — one forwards data, one serves snapshots
    forward_thread = Thread.new do
      pull = Cztop::Socket::PULL.bind(pub_ep)
      pub  = Cztop::Socket::PUB.bind(sub_ep)
      pull.recv_timeout = 2

      loop do
        msg = pull.receive.first
        topic, value = msg.split(' ', 2)
        cache_mu.synchronize { cache[topic] = value }
        pub << msg
      rescue IO::TimeoutError
        break
      end
    end

    snapshot_thread = Thread.new do
      snap = Cztop::Socket::REP.bind(snapshot_ep)
      snap.recv_timeout = 3

      loop do
        snap.receive
        cached = cache_mu.synchronize { cache.dup }
        snap << cached.map { |k, v| "#{k} #{v}" }.join("\n")
        puts "  cache: snapshot served (#{cached.size} entries)"
      rescue IO::TimeoutError
        break
      end
    end

    sleep 0.01

    # Publisher: sends weather data
    push = Cztop::Socket::PUSH.connect(pub_ep)
    5.times do |i|
      push << "weather.nyc #{70 + i}F"
      push << "weather.sfo #{60 + i}F"
      sleep 0.01
    end

    # Wait for all messages to be cached
    sleep 0.1

    # Late joiner: requests snapshot
    req = Cztop::Socket::REQ.connect(snapshot_ep)
    req.recv_timeout = 2
    req << 'SNAPSHOT'
    snapshot = req.receive.first
    snapshot.split("\n").each do |line|
      received_late << line
      puts "  late joiner (snapshot): #{line}"
    end
    req.close

    [forward_thread, snapshot_thread].each { |t| t.join(5) }

    refute_empty received_late, 'late joiner should receive cached values'
    assert(received_late.any? { |m| m.include?('weather.nyc') }, 'should have NYC data')
    assert(received_late.any? { |m| m.include?('weather.sfo') }, 'should have SFO data')
    puts "  summary: late joiner got #{received_late.size} cached entries"
  end
end
