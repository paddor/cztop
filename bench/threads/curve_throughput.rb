# frozen_string_literal: true

require 'cztop'
require 'benchmark/ips'

unless CZTop::CURVE.available?
  puts 'CURVE not available — skipping benchmark'
  exit
end

MSG_SIZES = [64, 256, 1024, 4096]

puts "CZMQ #{CZMQ::FFI::CZMQ_VERSION} | ZMQ #{CZMQ::FFI::ZMQ_VERSION} | Ruby #{RUBY_VERSION} (Threads, CURVE)"
puts

server_pub, server_sec = CZTop::CURVE.keypair
_, client_sec = CZTop::CURVE.keypair
auth = CZTop::CURVE::Auth.new(allow_any: true)

begin
  MSG_SIZES.each do |size|
    payload = 'x' * size

    puts "--- #{size}B ---"

    # Plaintext
    plain_pull = CZTop::Socket::PULL.new('tcp://127.0.0.1:*')
    plain_port = plain_pull.last_tcp_port
    plain_push = CZTop::Socket::PUSH.new("tcp://127.0.0.1:#{plain_port}")

    100.times do
      plain_push << payload
      plain_pull.receive
    end

    # CURVE
    curve_pull = CZTop::Socket::PULL.new('tcp://127.0.0.1:*',
                   curve: { secret_key: server_sec })
    curve_port = curve_pull.last_tcp_port
    curve_push = CZTop::Socket::PUSH.new("tcp://127.0.0.1:#{curve_port}",
                   curve: { secret_key: client_sec, server_key: server_pub })

    100.times do
      curve_push << payload
      curve_pull.receive
    end

    Benchmark.ips do |x|
      x.config(warmup: 1, time: 3)

      x.report('plaintext') do
        plain_push << payload
        plain_pull.receive
      end

      x.report('CURVE') do
        curve_push << payload
        curve_pull.receive
      end

      x.compare!
    end

    puts
  end
ensure
  auth.stop
end
