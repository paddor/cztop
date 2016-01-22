#! /usr/bin/env ruby
require_relative "../lib/cztop"
require "benchmark"

if ARGV.size != 2
  abort <<MSG
Usage: #{$0} <message-size> <message-count>
MSG
end

MSG_SIZE = Integer(ARGV[0]) # bytes
MSG_COUNT = Integer(ARGV[1]) # number of messages
MSG = "X" * MSG_SIZE

Thread.new do
  s = CZTop::Socket::PAIR.new("@inproc://perf")
  s.signal
  MSG_COUNT.times do
    msg = s.receive
    raise "wrong message size" if msg.content_size != MSG_SIZE
  end
end

s = CZTop::Socket::PAIR.new(">inproc://perf")
s.wait

tms = Benchmark.measure do
  MSG_COUNT.times do
    s << MSG
  end
end

elapsed = tms.real

throughput = MSG_COUNT / elapsed
megabits = (throughput * MSG_SIZE * 8) / 1_000_000

puts "message size: #{MSG_SIZE} [B]"
puts "message count: #{MSG_COUNT}"
puts "elapsed time: %.3f [s]" % elapsed
puts "mean throughput: %d [msg/s]" % throughput
puts "mean throughput: %.3f [Mb/s]" % megabits
