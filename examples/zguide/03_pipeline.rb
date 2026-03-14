#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'

# ZGuide Chapter 1 — Pipeline (Divide and Conquer)
# A ventilator pushes work items to workers via PUSH/PULL.
# Workers process items and push results to a sink.
# Demonstrates fan-out/fan-in with load balancing across workers.

describe 'Pipeline' do
  it 'distributes work across multiple workers and collects results' do
    vent_ep = 'inproc://zg03_vent'
    sink_ep = 'inproc://zg03_sink'
    n_tasks   = 20
    n_workers = 3
    results   = Queue.new
    worker_counts = Hash.new(0)
    mu = Mutex.new

    # Sink
    sink_thread = Thread.new do
      sink = Cztop::Socket::PULL.bind(sink_ep)
      sink.recv_timeout = 2
      n_tasks.times do
        msg = sink.receive.first
        results << msg
        worker_id = msg.split(':').first
        mu.synchronize { worker_counts[worker_id] += 1 }
        puts "  sink: #{msg}"
      end
    end

    # Workers
    worker_threads = n_workers.times.map do |id|
      Thread.new do
        pull = Cztop::Socket::PULL.connect(vent_ep)
        push = Cztop::Socket::PUSH.connect(sink_ep)
        pull.recv_timeout = 2
        loop do
          task = pull.receive.first
          break if task == 'END'
          push << "worker-#{id}:#{task}"
        rescue IO::TimeoutError
          break
        end
      end
    end

    sleep 0.02

    # Ventilator
    vent = Cztop::Socket::PUSH.bind(vent_ep)
    sleep 0.02 # let workers connect
    n_tasks.times { |i| vent << "task-#{i}" }
    n_workers.times { vent << 'END' }

    sink_thread.join(5)
    worker_threads.each { |t| t.join(3) }

    collected = []
    collected << results.pop until results.empty?

    assert_equal n_tasks, collected.size
    assert(worker_counts.size > 1, 'expected multiple workers to participate')
    puts "  summary: #{collected.size} results from #{worker_counts.size} workers"
    worker_counts.each { |id, count| puts "    #{id}: #{count} items" }
  end
end
