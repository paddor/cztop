#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'
require 'async'
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
#
# Frontend + dispatcher run in threads. Client runs inside Sync { }.

describe 'Titanic' do
  it 'persists requests to disk and serves results asynchronously' do
    frontend_ep = 'inproc://zg09_frontend'
    dispatch_ep = 'inproc://zg09_dispatch'
    results     = {}

    store_dir = Dir.mktmpdir('titanic')

    frontend = Thread.new do
      rep = Cztop::Socket::REP.bind(frontend_ep)
      rep.recv_timeout = 2
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
            rep << "OK|#{File.read(result_file)}"
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

    dispatcher = Thread.new do
      pull = Cztop::Socket::PULL.connect(dispatch_ep)
      pull.recv_timeout = 2

      loop do
        ticket = pull.receive.first
        req_file = File.join(store_dir, "#{ticket}.req")
        next unless File.exist?(req_file)

        req = JSON.parse(File.read(req_file))
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

    Sync do
      client = Cztop::Socket::REQ.connect(frontend_ep)
      client.recv_timeout = 2

      # Submit 3 requests
      tickets = [['echo', 'hello'], ['upper', 'world'], ['echo', 'foo']].map do |service, body|
        client << "SUBMIT|#{service}|#{body}"
        reply = client.receive.first
        status, ticket = reply.split('|', 2)
        assert_equal 'TICKET', status
        puts "  client: submitted #{service}(#{body}) -> ticket #{ticket[0..7]}.."
        ticket
      end

      # Wait for dispatcher to process
      sleep 0.1

      # Poll for results
      tickets.each do |ticket|
        client << "RESULT|#{ticket}"
        reply = client.receive.first
        status, result = reply.split('|', 2)
        assert_equal 'OK', status, "expected result for #{ticket[0..7]}.."
        results[ticket] = result
        puts "  client: result for #{ticket[0..7]}.. -> #{result}"
      end
    end

    [frontend, dispatcher].each { |t| t.join(5) }
    FileUtils.rm_rf(store_dir)

    assert_equal 3, results.size
    assert(results.values.any? { |r| r.start_with?('echo:') })
    assert(results.values.any? { |r| r == 'WORLD' })
    puts "  summary: #{results.size} requests persisted, dispatched, and retrieved"
  end
end
