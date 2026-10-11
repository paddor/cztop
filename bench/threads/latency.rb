# frozen_string_literal: true

require_relative '../helper'

CZTopBench.print_environment('Threads')
payload = 'ping'

CZTopBench::TRANSPORTS.each do |transport|
  puts "--- #{transport} ---"

  CZTopBench.with_sockets(transport, CZTop::Socket::REP, CZTop::Socket::REQ) do |rep, req|
    responder = Thread.new do
      loop { rep << rep.receive }
    end

    begin
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
    ensure
      responder.kill
      responder.join
    end
  end
  puts
end
