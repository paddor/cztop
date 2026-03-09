#!/usr/bin/env ruby
# frozen_string_literal: true

require "cztop"
require "async"
require "async/barrier"
require "benchmark"

ENDPOINTS = [
  "inproc://req_rep_example0",
  "inproc://req_rep_example1",
  "inproc://req_rep_example2",
  "ipc:///tmp/req_rep_example0",
  "tcp://localhost:5556",
]

REQ_SOCKETS   = 200
REQUESTS      = 1000 # per REQ socket
PROGRESS_STEP = 1000 # requests per '.' printed

puts "#{ENDPOINTS.size} REP sockets serving requests from #{REQ_SOCKETS} REQ sockets."
puts "Each REQ socket will send #{REQUESTS} requests."
puts ". = #{PROGRESS_STEP} requests"

Async do |task|
  rep_task = Async do |task|
    ENDPOINTS.each do |endpoint|
      task.async do
        socket = CZTop::Socket::REP.new(endpoint)
        n = 0

        loop do
          msg = socket.receive.to_a
          socket << msg.map(&:upcase)
          n += 1
        end
      ensure
        puts "REP at #{endpoint} served #{n} requests."
      end
    end
  end

  n = 0

  realtime = Benchmark.realtime do
    req_task = Async do
      barrier = Async::Barrier.new

      REQ_SOCKETS.times do
        barrier.async do
          socket = CZTop::Socket::REQ.new

          ENDPOINTS.each do |endpoint|
            socket.connect(endpoint)
          end

          REQUESTS.times do |i|
            socket << "foobar ##{i}"
            socket.receive
            n += 1
            print "." if n % PROGRESS_STEP == 0
          end
        end
      end

      barrier.wait
    end

    req_task.wait
    puts
    rep_task.stop
  end

  rps = n / realtime / 1000
  puts "#{n} requests in %.2fs = %.1fk r/s" % [realtime, rps]
end
