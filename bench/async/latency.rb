# frozen_string_literal: true

require_relative '../helper'
require 'async'

CZTopBench.print_environment('Async')
payload = 'ping'

CZTopBench::TRANSPORTS.each do |transport|
  puts "--- #{transport} ---"

  Async do |task|
    CZTopBench.with_sockets(transport, CZTop::Socket::REP, CZTop::Socket::REQ) do |rep, req|
      responder = task.async do
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
        responder.stop
      end
    end
  end
  puts
end
