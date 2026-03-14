#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'
require 'securerandom'
require 'json'
require 'tempfile'

# ZGuide Chapter 4 — Titanic Pattern
# Disconnected reliability via disk-based store-and-forward. The broker
# persists requests to disk before forwarding to workers. Clients get a
# ticket ID and poll for results later. Requests survive broker restarts.
#
# Three roles:
#   1. Frontend: accepts client requests, writes to disk, returns ticket
#   2. Dispatcher: reads pending requests, sends to workers, writes results
#   3. Client: submits request, polls for result by ticket

describe 'Titanic' do
  it 'persists requests to disk and serves results asynchronously' do
    frontend_ep   = 'inproc://zg09_frontend'
    dispatch_ep   = 'inproc://zg09_dispatch'
    results       = {}
    results_mu    = Mutex.new

    # Disk store (simulated with a temp directory)
    store_dir = Dir.mktmpdir('titanic')

    # Frontend: accepts requests, writes to disk, returns ticket
    frontend_thread = Thread.new do
      rep = Cztop::Socket::REP.bind(frontend_ep)
      rep.recv_timeout = 2

      # Also notify dispatcher of new work
      push = Cztop::Socket::PUSH.bind(dispatch_ep)

      loop do
        msg = rep.receive.first
        command, *args = msg.split('|', 3)

        case command
        when 'SUBMIT'
          service, body = args
          ticket = SecureRandom.hex(8)
          File.write(File.join(store_dir, "#{ticket}.req"), { service: service, body: body }.to_json)
          rep << "TICKET|#{ticket}"
          push << ticket
          puts "  frontend: accepted #{ticket[0..7]}.. for '#{service}'"

        when 'RESULT'
          ticket = args[0]
          result_file = File.join(store_dir, "#{ticket}.res")
          if File.exist?(result_file)
            result = File.read(result_file)
            rep << "OK|#{result}"
            puts "  frontend: served result for #{ticket[0..7]}.."
          else
            rep << 'PENDING'
          end

        else
          rep << 'ERROR|unknown command'
        end
      rescue IO::TimeoutError
        break
      end
    end

    # Dispatcher: reads pending tickets, sends to workers, writes results
    dispatcher_thread = Thread.new do
      pull = Cztop::Socket::PULL.connect(dispatch_ep)
      pull.recv_timeout = 2

      loop do
        ticket = pull.receive.first
        req_file = File.join(store_dir, "#{ticket}.req")
        next unless File.exist?(req_file)

        req = JSON.parse(File.read(req_file))

        # Process locally (in a real system, this would route to a worker)
        result = case req['service']
                 when 'echo'  then "echo:#{req['body']}"
                 when 'upper' then req['body'].upcase
                 else "unknown service: #{req['service']}"
                 end

        File.write(File.join(store_dir, "#{ticket}.res"), result)
        puts "  dispatcher: processed #{ticket[0..7]}.. -> #{result}"
      rescue IO::TimeoutError
        break
      end
    end

    sleep 0.02

    # Client: submit requests, get tickets, poll for results
    tickets = []
    client = Cztop::Socket::REQ.connect(frontend_ep)
    client.recv_timeout = 2

    # Submit 3 requests
    [['echo', 'hello'], ['upper', 'world'], ['echo', 'foo']].each do |service, body|
      client << "SUBMIT|#{service}|#{body}"
      reply = client.receive.first
      status, ticket = reply.split('|', 2)
      assert_equal 'TICKET', status
      tickets << ticket
      puts "  client: submitted #{service}(#{body}) -> ticket #{ticket[0..7]}.."
    end

    # Wait for dispatcher to process
    sleep 0.1

    # Poll for results
    tickets.each do |ticket|
      client << "RESULT|#{ticket}"
      reply = client.receive.first
      status, result = reply.split('|', 2)
      assert_equal 'OK', status, "expected result for #{ticket[0..7]}.."
      results_mu.synchronize { results[ticket] = result }
      puts "  client: result for #{ticket[0..7]}.. -> #{result}"
    end

    [frontend_thread, dispatcher_thread].each { |t| t.join(5) }

    # Cleanup
    FileUtils.rm_rf(store_dir)

    assert_equal 3, results.size
    assert(results.values.any? { |r| r.start_with?('echo:') })
    assert(results.values.any? { |r| r == 'WORLD' })
    puts "  summary: #{results.size} requests persisted, dispatched, and retrieved"
  end
end
