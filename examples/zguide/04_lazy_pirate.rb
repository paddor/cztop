#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'
require 'async'

# ZGuide Chapter 4 — Lazy Pirate Pattern
# Client-side reliability via timeout + retry + socket recreation.
# The server simulates a crash (long delay) on one request.
# The client detects the timeout, closes the socket, creates a new one,
# and retries — demonstrating the core Lazy Pirate technique.
#
# Server runs in a thread. Client runs inside Sync { }.

describe 'Lazy Pirate' do
  it 'retries and recovers from an unresponsive server' do
    endpoint = 'inproc://zg04_lazy'
    replies  = []
    retries  = 0

    server = Thread.new do
      rep = Cztop::Socket::REP.bind(endpoint)
      rep.recv_timeout = 2
      handled = 0

      loop do
        msg = rep.receive.first
        handled += 1

        if handled == 3
          puts "  server: simulating crash on '#{msg}'"
          sleep 0.8
        end

        rep << "reply:#{msg}"
        puts "  server: replied to #{msg}"
      rescue IO::TimeoutError
        break
      end
    end

    sleep 0.01

    Sync do
      max_retries = 3
      5.times do |seq|
        attempts = 0

        loop do
          req = Cztop::Socket::REQ.connect(endpoint)
          req.recv_timeout = 0.3

          req << "request-#{seq}"
          begin
            reply = req.receive.first
            replies << reply
            puts "  client: request-#{seq} -> #{reply}"
            req.close
            break
          rescue IO::TimeoutError
            retries += 1
            attempts += 1
            puts "  client: timeout on request-#{seq}, retry #{attempts}"
            req.close
            break if attempts >= max_retries
          end
        end
      end
    end

    server.join(3)

    puts "  summary: #{replies.size} replies, #{retries} retries"
    assert retries > 0, 'expected at least one retry'
    assert replies.size >= 3, 'expected most requests to succeed'
  end
end
