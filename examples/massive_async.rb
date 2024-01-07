#! /usr/bin/env ruby

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'async'
  gem 'cztop', path: '../../'
  gem 'benchmark'
end

require 'async/barrier'

ENDPOINTS = [
  'inproc://req_rep_example0',
  'inproc://req_rep_example1',
  'inproc://req_rep_example2',
  'ipc:///tmp/req_rep_example0',
  # 'ipc:///tmp/req_rep_example1',
  # 'ipc://req_rep_example2',
  'tcp://localhost:5556',
  # 'tcp://localhost:5557',
  # 'tcp://localhost:5558',
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
        socket = CZTop::Socket::REP.new endpoint
        n = 0

        while true
          msg = socket.receive.to_a
          # puts "<<< #{msg.to_a.inspect}"
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

      REQ_SOCKETS.times.map do |i|
        barrier.async do
          socket = CZTop::Socket::REQ.new
          # socket.options.rcvtimeo = 1000 # ms

          ENDPOINTS.each do |endpoint|
            socket.connect endpoint
          end

          REQUESTS.times do |i|
            socket << "foobar ##{i}"
            msg = socket.receive
            n += 1
            print '.' if n % PROGRESS_STEP == 0
            # puts ">>> #{msg.to_a.inspect}"
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

