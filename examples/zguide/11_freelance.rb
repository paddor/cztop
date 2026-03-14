#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'
require 'async'

# ZGuide Chapter 4 — Freelance Pattern
# Brokerless reliability: client talks directly to multiple servers.
# Three models demonstrated:
#   1. Sequential failover — try servers in order, skip on timeout
#   2. Shotgun — blast to all, take first reply
#   3. Tracked — remember which server is alive, prefer it
#
# Servers run in threads. Client code runs inside Sync { }.

describe 'Freelance' do
  def start_server(endpoint, name, delay: 0)
    Thread.new do
      rep = Cztop::Socket::REP.bind(endpoint)
      rep.recv_timeout = 2
      loop do
        msg = rep.receive.first
        sleep delay if delay > 0
        rep << "#{name}:#{msg}"
        puts "  #{name}: served #{msg}"
      rescue IO::TimeoutError
        break
      end
    end
  end


  it 'model 1: sequential failover on timeout' do
    ep1 = 'inproc://zg11a_server1'
    ep2 = 'inproc://zg11a_server2'
    ep3 = 'inproc://zg11a_server3'

    s2 = start_server(ep2, 'server2')
    sleep 0.01

    replies = Sync do
      endpoints = [ep1, ep2, ep3]

      3.times.map do |i|
        reply = nil
        endpoints.each do |ep|
          req = Cztop::Socket::REQ.connect(ep)
          req.recv_timeout = 0.15
          req.linger = 0
          req << "request-#{i}"
          begin
            reply = req.receive.first
            req.close
            break
          rescue IO::TimeoutError
            puts "  client: timeout on #{ep}, trying next"
            req.close
          end
        end
        reply
      end
    end

    s2.join(3)

    assert(replies.all? { |r| r&.start_with?('server2:') }, 'all should come from server2')
    puts "  summary: #{replies.size} requests, all served by server2 after failover"
  end


  it 'model 2: shotgun — blast to all, take first reply' do
    ep1 = 'inproc://zg11b_server1'
    ep2 = 'inproc://zg11b_server2'

    s1 = start_server(ep1, 'fast', delay: 0)
    s2 = start_server(ep2, 'slow', delay: 0.3)
    sleep 0.01

    first_reply = Sync do
      dealer = Cztop::Socket::DEALER.new
      dealer.connect(ep1)
      dealer.connect(ep2)
      dealer.recv_timeout = 1

      dealer << ['', 'shotgun-req']
      dealer << ['', 'shotgun-req']

      reply = dealer.receive
      result = reply.last
      puts "  client: first reply = #{result}"
      dealer.close
      result
    end

    [s1, s2].each { |t| t.join(2) }

    assert first_reply.end_with?('shotgun-req')
    assert first_reply.start_with?('fast:'), "expected fast server first, got: #{first_reply}"
  end


  it 'model 3: tracked — remember which server is alive' do
    ep1 = 'inproc://zg11c_server1'
    ep2 = 'inproc://zg11c_server2'

    s1 = start_server(ep1, 'server1')
    s2 = start_server(ep2, 'server2')
    sleep 0.01

    replies = Sync do
      known_good = nil
      endpoints = [ep1, ep2]

      6.times.map do |i|
        try_order = known_good ? [known_good] + (endpoints - [known_good]) : endpoints
        reply = nil

        try_order.each do |ep|
          req = Cztop::Socket::REQ.connect(ep)
          req.recv_timeout = 0.2
          req.linger = 0
          req << "request-#{i}"
          begin
            reply = req.receive.first
            known_good = ep
            puts "  client: #{reply} (via #{ep})"
            req.close
            break
          rescue IO::TimeoutError
            puts "  client: #{ep} timed out, rotating"
            known_good = nil if known_good == ep
            req.close
          end
        end

        # Kill server1 after 3 requests
        if i == 2
          puts "  --- server1 goes down ---"
          s1.kill
        end

        reply
      end
    end

    s2.join(3)

    assert_equal 6, replies.size
    early = replies[0..2]
    late  = replies[3..5]
    assert(early.any? { |r| r.start_with?('server1:') }, 'early requests should hit server1')
    assert(late.all? { |r| r.start_with?('server2:') }, 'late requests should all hit server2')
    puts "  summary: #{replies.size} requests, seamless failover from server1 to server2"
  end
end
