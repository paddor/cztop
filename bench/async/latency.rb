# frozen_string_literal: true

require 'cztop'
require 'async'
require 'benchmark/ips'

TRANSPORTS = {
  'inproc' => 'inproc://bench_latency',
  'ipc'    => 'ipc:///tmp/cztop_bench_latency.sock',
  'tcp'    => 'tcp://127.0.0.1:9100',
}

puts "CZMQ #{CZMQ::FFI::CZMQ_VERSION} | ZMQ #{CZMQ::FFI::ZMQ_VERSION} | Ruby #{RUBY_VERSION}"
puts

payload = 'ping'

TRANSPORTS.each do |transport, addr|
  puts "--- #{transport} ---"

  Async do |task|
    rep = CZTop::Socket::REP.new(addr)
    req = CZTop::Socket::REQ.new(addr)

    responder = task.async do
      loop do
        msg = rep.receive
        rep << msg
      end
    end

    # Warm up
    100.times do
      req << payload
      req.receive
    end

    Benchmark.ips do |x|
      x.config(warmup: 1, time: 3)

      x.report('roundtrip') do
        req << payload
        req.receive
      end
    end

    responder.stop
  end

  puts
end
