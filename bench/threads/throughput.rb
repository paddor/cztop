# frozen_string_literal: true

require 'cztop'
require 'benchmark/ips'

MSG_SIZES = [64, 256, 1024, 4096]
TRANSPORTS = {
  'inproc' => ->(tag) { "inproc://bench_tp_t_#{tag}" },
  'ipc'    => ->(tag) { "ipc:///tmp/cztop_bench_tp_t_#{tag}.sock" },
  'tcp'    => ->(tag) { "tcp://127.0.0.1:#{9000 + tag.hash.abs % 1000}" },
}

puts "CZMQ #{CZMQ::FFI::CZMQ_VERSION} | ZMQ #{CZMQ::FFI::ZMQ_VERSION} | Ruby #{RUBY_VERSION} (Threads)"
puts

TRANSPORTS.each do |transport, addr_fn|
  puts "--- #{transport} ---"

  MSG_SIZES.each do |size|
    payload = 'x' * size
    addr = addr_fn.call("#{transport}_#{size}")

    pull = CZTop::Socket::PULL.new(addr)
    push = CZTop::Socket::PUSH.new(addr)

    # Warm up
    100.times do
      push << payload
      pull.receive
    end

    Benchmark.ips do |x|
      x.config(warmup: 1, time: 3)

      x.report("#{size}B") do
        push << payload
        pull.receive
      end
    end
  end

  puts
end
