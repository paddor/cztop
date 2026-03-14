#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'

# ZGuide Chapter 2 — Publish-Subscribe
# Topic filtering, fan-out to multiple subscribers, and an XPUB/XSUB
# forwarding proxy. Demonstrates fire-and-forget data distribution
# with prefix-based topic filtering.

describe 'Publish-Subscribe' do
  it 'filters messages by topic prefix' do
    endpoint = 'inproc://zg02_filter'
    received_nyc = []
    received_sfo = []

    pub_thread = Thread.new do
      pub = Cztop::Socket::PUB.bind(endpoint)
      sleep 0.02 # let subscribers connect
      10.times do |i|
        pub << "weather.nyc #{60 + i}F"
        pub << "weather.sfo #{50 + i}F"
        pub << "sports.nba score-#{i}"
      end
    end

    nyc_thread = Thread.new do
      sub = Cztop::Socket::SUB.connect(endpoint, prefix: 'weather.nyc')
      sub.recv_timeout = 1
      loop do
        msg = sub.receive.first
        received_nyc << msg
        puts "  nyc: #{msg}"
      rescue IO::TimeoutError
        break
      end
    end

    sfo_thread = Thread.new do
      sub = Cztop::Socket::SUB.connect(endpoint, prefix: 'weather.sfo')
      sub.recv_timeout = 1
      loop do
        msg = sub.receive.first
        received_sfo << msg
        puts "  sfo: #{msg}"
      rescue IO::TimeoutError
        break
      end
    end

    [pub_thread, nyc_thread, sfo_thread].each(&:join)

    assert(received_nyc.all? { |m| m.start_with?('weather.nyc') })
    assert(received_sfo.all? { |m| m.start_with?('weather.sfo') })
    refute_empty received_nyc
    refute_empty received_sfo
    puts "  summary: nyc=#{received_nyc.size}, sfo=#{received_sfo.size}"
  end


  it 'forwards messages through an XPUB/XSUB proxy' do
    upstream_ep   = 'inproc://zg02_upstream'
    downstream_ep = 'inproc://zg02_downstream'
    received = []

    # Proxy: XSUB (upstream) <-> XPUB (downstream)
    proxy_thread = Thread.new do
      xsub = Cztop::Socket::XSUB.bind(upstream_ep)
      xpub = Cztop::Socket::XPUB.bind(downstream_ep)
      xsub.recv_timeout = 1
      xpub.recv_timeout = 0.1

      loop do
        # Forward subscription events from XPUB to XSUB
        begin
          event = xpub.receive.first
          xsub << event
        rescue IO::TimeoutError
          # no new subscriptions
        end

        # Forward data from XSUB to XPUB
        begin
          msg = xsub.receive
          xpub << msg
        rescue IO::TimeoutError
          break
        end
      end
    end

    sleep 0.01

    sub_thread = Thread.new do
      sub = Cztop::Socket::SUB.connect(downstream_ep, prefix: 'data')
      sub.recv_timeout = 1
      loop do
        msg = sub.receive.first
        received << msg
        puts "  subscriber: #{msg}"
      rescue IO::TimeoutError
        break
      end
    end

    sleep 0.02

    pub = Cztop::Socket::PUB.connect(upstream_ep)
    sleep 0.02 # let subscription propagate
    5.times { |i| pub << "data.#{i}" }
    sleep 0.05 # let messages flow through proxy

    [proxy_thread, sub_thread].each { |t| t.join(3) }

    refute_empty received, 'expected subscriber to receive messages through proxy'
    assert(received.all? { |m| m.start_with?('data') })
    puts "  summary: #{received.size} messages forwarded through proxy"
  end
end
