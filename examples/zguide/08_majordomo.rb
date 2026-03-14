#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'

# ZGuide Chapter 4 — Majordomo Pattern
# A service-oriented broker. Workers register by service name.
# Clients request a service by name. The broker routes to the right
# worker pool. Demonstrates service discovery and LRU routing.
#
# Protocol (simplified):
#   Worker → Broker: ["READY", service_name]
#   Client → Broker: [service_name, request_body]
#   Broker → Worker: [client_identity, "", request_body]
#   Worker → Broker: [client_identity, "", reply_body]
#   Broker → Client: [reply_body]

describe 'Majordomo' do
  it 'routes requests to workers by service name' do
    frontend_ep = 'inproc://zg08_frontend'
    backend_ep  = 'inproc://zg08_backend'
    replies     = []

    # Broker: ROUTER (frontend for clients) + ROUTER (backend for workers)
    broker_thread = Thread.new do
      frontend = Cztop::Socket::ROUTER.bind(frontend_ep)
      backend  = Cztop::Socket::ROUTER.bind(backend_ep)
      frontend.recv_timeout = 2
      backend.recv_timeout  = 0.1

      # service_name => [worker_identity, ...]
      services = Hash.new { |h, k| h[k] = [] }

      # Register workers
      6.times do
        msg = backend.receive
        worker_id = msg[0]
        command   = msg[1]
        service   = msg[2]
        if command == 'READY'
          services[service] << worker_id
          puts "  broker: worker #{worker_id.unpack1('H*')[0..7]} registered for '#{service}'"
        end
      rescue IO::TimeoutError
        break
      end

      # Route client requests to workers, relay replies
      6.times do
        # Receive client request: [client_id, "", service_name, body]
        msg = frontend.receive
        client_id = msg[0]
        service   = msg[2]
        body      = msg[3]

        worker_id = services[service]&.shift
        unless worker_id
          puts "  broker: no worker for service '#{service}'"
          next
        end

        # Forward to worker: [worker_id, client_id, "", body]
        backend << [worker_id, client_id, '', body]
        puts "  broker: routed '#{service}' request to worker"

        # Receive worker reply: [worker_id, client_id, "", reply]
        reply_msg = backend.receive
        _wid       = reply_msg[0]
        reply_cid  = reply_msg[1]
        _delim     = reply_msg[2]
        reply_body = reply_msg[3]

        # Return worker to pool
        services[service] << _wid

        # Forward reply to client: [client_id, "", reply]
        frontend << [reply_cid, '', reply_body]
      end
    end

    # Workers: 2 "echo" workers, 1 "upper" worker
    worker_threads = []
    [['echo', 2], ['upper', 1]].each do |service, count|
      count.times do |id|
        worker_threads << Thread.new do
          sock = Cztop::Socket::DEALER.connect(backend_ep)
          sock.recv_timeout = 2

          # Register
          sock << ['READY', service]

          loop do
            msg = sock.receive
            client_id = msg[0]
            _delim    = msg[1]
            body      = msg[2]

            reply = case service
                    when 'echo'  then "echo:#{body}"
                    when 'upper' then body.upcase
                    end

            sock << [client_id, '', reply]
            puts "  worker(#{service}-#{id}): #{body} -> #{reply}"
          rescue IO::TimeoutError
            break
          end
        end
      end
    end

    sleep 0.03

    # Clients: send requests to different services
    requests = [
      ['echo',  'hello'],
      ['echo',  'world'],
      ['upper', 'foo'],
      ['echo',  'test'],
      ['upper', 'bar'],
      ['upper', 'baz'],
    ]

    client_threads = requests.map do |service, body|
      Thread.new do
        req = Cztop::Socket::REQ.connect(frontend_ep)
        req.recv_timeout = 2
        req << [service, body]
        reply = req.receive.first
        puts "  client: #{service}(#{body}) -> #{reply}"
        [service, reply]
      end
    end

    replies = client_threads.map(&:value)
    broker_thread.join(5)
    worker_threads.each { |t| t.join(2) }

    echo_replies = replies.select { |s, _| s == 'echo' }.map(&:last)
    upper_replies = replies.select { |s, _| s == 'upper' }.map(&:last)

    assert(echo_replies.all? { |r| r.start_with?('echo:') }, 'echo workers should echo')
    assert(upper_replies.all? { |r| r == r.upcase }, 'upper workers should upcase')
    assert_equal requests.size, replies.size
    puts "  summary: #{replies.size} requests routed across #{2} services"
  end
end
