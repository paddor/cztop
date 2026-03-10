# frozen_string_literal: true

require 'cztop'
require 'benchmark/ips'

TRANSPORTS = {
  'inproc' => 'inproc://bench_latency_t',
  'ipc'    => 'ipc:///tmp/cztop_bench_latency_t.sock',
  'tcp'    => 'tcp://127.0.0.1:9200',
}

puts "CZMQ #{CZMQ::FFI::CZMQ_VERSION} | ZMQ #{CZMQ::FFI::ZMQ_VERSION} | Ruby #{RUBY_VERSION} (Threads)"
puts

payload = 'ping'

TRANSPORTS.each do |transport, addr|
  puts "--- #{transport} ---"

  rep = CZTop::Socket::REP.new(addr)
  req = CZTop::Socket::REQ.new(addr)

  responder = Thread.new do
    loop do
      msg = rep.receive
      rep << msg
    rescue IOError, SystemCallError
      break
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

  responder.kill
  puts
end
