#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'
require 'async'

# ZGuide Chapter 1 — Request-Reply
# Basic REQ/REP echo, then a multi-worker broker using ROUTER/DEALER.
# Demonstrates the fundamental request-reply pattern and how to scale
# it with a broker that load-balances across workers.
#
# Server-side sockets run in threads (ZMQ sockets are thread-bound).
# Client code runs inside Sync { } — Fiber Scheduler-driven I/O.

describe 'Request-Reply' do
  it 'echoes messages between REQ and REP' do
    endpoint = 'inproc://zg01_basic'

    server = Thread.new do
      rep = Cztop::Socket::REP.bind(endpoint)
      rep.recv_timeout = 1
      3.times do
        msg = rep.receive
        rep << "echo:#{msg.first}"
      end
    end

    sleep 0.01

    replies = Sync do
      req = Cztop::Socket::REQ.connect(endpoint)
      req.recv_timeout = 1

      3.times.map do |i|
        req << "hello-#{i}"
        reply = req.receive.first
        puts "  client: hello-#{i} -> #{reply}"
        reply
      end
    end

    server.join

    assert_equal %w[echo:hello-0 echo:hello-1 echo:hello-2], replies
  end


  it 'brokers requests across multiple workers via ROUTER/DEALER' do
    frontend_ep = 'inproc://zg01_frontend'
    backend_ep  = 'inproc://zg01_backend'
    n_workers   = 3
    n_requests  = 9
    worker_ids  = []
    mu          = Mutex.new

    # Broker: ROUTER (frontend) <-> DEALER (backend)
    broker = Thread.new do
      frontend = Cztop::Socket::ROUTER.bind(frontend_ep)
      backend  = Cztop::Socket::DEALER.bind(backend_ep)
      frontend.recv_timeout = 1
      backend.recv_timeout  = 1

      fwd = Thread.new { n_requests.times { backend << frontend.receive } }
      ret = Thread.new { n_requests.times { frontend << backend.receive } }

      [fwd, ret].each(&:join)
    end

    # Workers
    workers = n_workers.times.map do |id|
      Thread.new do
        rep = Cztop::Socket::REP.connect(backend_ep)
        rep.recv_timeout = 1
        loop do
          msg = rep.receive
          mu.synchronize { worker_ids << id }
          rep << "worker-#{id}:#{msg.first}"
          puts "  worker-#{id}: handled #{msg.first}"
        rescue IO::TimeoutError
          break
        end
      end
    end

    sleep 0.02

    # Client: Fiber Scheduler-driven I/O
    replies = Sync do
      req = Cztop::Socket::REQ.connect(frontend_ep)
      req.recv_timeout = 1

      n_requests.times.map do |i|
        req << "request-#{i}"
        reply = req.receive.first
        puts "  client: request-#{i} -> #{reply}"
        reply
      end
    end

    broker.join
    workers.each { |t| t.join(2) }

    assert_equal n_requests, replies.size
    assert(worker_ids.uniq.size > 1, 'expected multiple workers to participate')
    puts "  summary: #{replies.size} replies from #{worker_ids.uniq.size} workers"
  end
end
