# frozen_string_literal: true

require_relative '../helper'

unless CZTop::CURVE.available?
  puts 'CURVE not available; skipping benchmark'
  exit
end

CZTopBench.print_environment('Threads, CURVE')

server_pub, server_sec = CZTop::CURVE.keypair
_, client_sec = CZTop::CURVE.keypair
auth = CZTop::CURVE::Auth.new(allow_any: true)

begin
  CZTopBench::MSG_SIZES.each do |size|
    payload = 'x' * size
    puts "--- #{size}B ---"

    begin
      plain_pull = CZTop::Socket::PULL.bind('tcp://127.0.0.1:*')
      plain_push = CZTop::Socket::PUSH.connect(plain_pull.last_endpoint)
      curve_pull = CZTop::Socket::PULL.bind('tcp://127.0.0.1:*',
        curve: { secret_key: server_sec })
      curve_push = CZTop::Socket::PUSH.connect(curve_pull.last_endpoint,
        curve: { secret_key: client_sec, server_key: server_pub })

      100.times do
        plain_push << payload
        plain_pull.receive
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
    ensure
      [plain_push, plain_pull, curve_push, curve_pull].each { |socket| socket&.close }
    end
    puts
  end
ensure
  auth.stop
end
