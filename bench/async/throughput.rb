# frozen_string_literal: true

require_relative '../helper'
require 'async'

CZTopBench.print_environment('Async')

CZTopBench::TRANSPORTS.each do |transport|
  puts "--- #{transport} ---"

  CZTopBench::MSG_SIZES.each do |size|
    payload = 'x' * size
    Async do
      CZTopBench.with_sockets(transport, CZTop::Socket::PULL, CZTop::Socket::PUSH) do |pull, push|
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
    end
  end
  puts
end
