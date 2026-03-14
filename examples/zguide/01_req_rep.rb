#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'

# ZGuide Chapter 1 — Request-Reply
# Basic REQ/REP echo, then a multi-worker broker using ROUTER/DEALER.
# Demonstrates the fundamental request-reply pattern and how to scale
# it with a broker that load-balances across workers.

describe 'Request-Reply' do
  it 'echoes messages between REQ and REP' do
    endpoint = 'inproc://zg01_basic'
    replies = []

    rep_thread = Thread.new do
      rep = Cztop::Socket::REP.bind(endpoint)
      rep.recv_timeout = 1
      3.times do
        msg = rep.receive
        rep << "echo:#{msg.first}"
      end
    end

    sleep 0.01

    req = Cztop::Socket::REQ.connect(endpoint)
    req.recv_timeout = 1
    3.times do |i|
      req << "hello-#{i}"
      replies << req.receive.first
      puts "  client: sent hello-#{i}, got #{replies.last}"
    end

    rep_thread.join

    assert_equal %w[echo:hello-0 echo:hello-1 echo:hello-2], replies
  end


  it 'brokers requests across multiple workers via ROUTER/DEALER' do
    frontend_ep = 'inproc://zg01_frontend'
    backend_ep  = 'inproc://zg01_backend'
    n_workers   = 3
    n_requests  = 9
    replies     = []
    workers_seen = Mutex.new
    worker_ids   = []

    # Broker: ROUTER (frontend) <-> DEALER (backend)
    broker_thread = Thread.new do
      frontend = Cztop::Socket::ROUTER.bind(frontend_ep)
      backend  = Cztop::Socket::DEALER.bind(backend_ep)
      frontend.recv_timeout = 1
      backend.recv_timeout  = 1

      threads = []

      # Frontend -> Backend
      threads << Thread.new do
        n_requests.times do
          msg = frontend.receive
          backend << msg
        end
      end

      # Backend -> Frontend
      threads << Thread.new do
        n_requests.times do
          msg = backend.receive
          frontend << msg
        end
      end

      threads.each(&:join)
    end

    # Workers
    worker_threads = n_workers.times.map do |id|
      Thread.new do
        rep = Cztop::Socket::REP.connect(backend_ep)
        rep.recv_timeout = 1

        loop do
          msg = rep.receive
          workers_seen.synchronize { worker_ids << id }
          rep << "worker-#{id}:#{msg.first}"
          puts "  worker-#{id}: handled #{msg.first}"
        rescue IO::TimeoutError
          break
        end
      end
    end

    sleep 0.02

    # Clients
    client_threads = n_requests.times.map do |i|
      Thread.new do
        req = Cztop::Socket::REQ.connect(frontend_ep)
        req.recv_timeout = 1
        req << "request-#{i}"
        reply = req.receive.first
        puts "  client: request-#{i} -> #{reply}"
        reply
      end
    end

    replies = client_threads.map(&:value)
    broker_thread.join
    worker_threads.each { |t| t.join(2) }

    assert_equal n_requests, replies.size
    assert(worker_ids.uniq.size > 1, 'expected multiple workers to participate')
    puts "  summary: #{replies.size} replies from #{worker_ids.uniq.size} workers"
  end
end
