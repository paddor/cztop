#! /usr/bin/env ruby
require_relative "../lib/cztop"
require "benchmark"
#require "ruby-prof"

if ARGV.size != 2
  abort <<MSG
Usage: #{$0} <message-size> <roundtrip-count>
MSG
end

MSG_SIZE = Integer(ARGV[0]) # bytes
ROUNDTRIP_COUNT = Integer(ARGV[1]) # round trips
MSG = "X" * MSG_SIZE

Thread.new do
  s = CZTop::Socket::REP.new("@inproc://lat")
  ROUNDTRIP_COUNT.times do
    msg = s.receive
    raise "wrong message size" if msg.content_size != MSG_SIZE
    s << msg
  end
end

s = CZTop::Socket::REQ.new(">inproc://lat")
sleep 0.1

#RubyProf.start
tms = Benchmark.measure do
  ROUNDTRIP_COUNT.times do
    s << MSG
    msg = s.receive
    raise "wrong message size" if msg.content_size != MSG_SIZE
  end
end
#rubyprof_result = RubyProf.stop

elapsed = tms.real
latency = elapsed / (ROUNDTRIP_COUNT * 2) * 1_000_000
puts "message size: #{MSG_SIZE} [B]"
puts "roundtrip count: #{ROUNDTRIP_COUNT}"
puts "elapsed time: %.3f [s]" % elapsed
puts "average latency: %.3f [us]" % latency

# print a flat profile to text
#printer = RubyProf::FlatPrinter.new(rubyprof_result)
#printer.print(STDOUT)

