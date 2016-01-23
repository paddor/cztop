#! /usr/bin/env ruby
require "cztop"
require "benchmark"

if ARGV.size != 3
  abort <<MSG
Usage: #{$0} <connect-to> <message-size> <roundtrip-count>
MSG
end

ENDPOINT = ARGV[0]
MSG_SIZE = Integer(ARGV[1]) # bytes
ROUNDTRIP_COUNT = Integer(ARGV[2]) # round trips
MSG = "X" * MSG_SIZE

s = CZTop::Socket::REQ.new(ENDPOINT)

# synchronize
s.signal
s.wait

ROUNDTRIP_COUNT.times do
  s << MSG
  msg = s.receive
  raise "wrong message size" if msg.content_size != MSG_SIZE
end
