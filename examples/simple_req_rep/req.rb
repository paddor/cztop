#!/usr/bin/env ruby
# frozen_string_literal: true

require "cztop"

socket = CZTop::Socket::REQ.new("ipc:///tmp/req_rep_example")
puts ">>> Socket connected."

# simple string
socket << "foobar"
puts ">>> #{socket.receive.inspect}"

# multi-frame message as array
socket << %w[foo bar baz]
puts ">>> #{socket.receive.inspect}"

# multi-frame message
socket << %w[bla another\ frame]
puts ">>> #{socket.receive.inspect}"

# optional: send N additional messages
if ARGV.first
  ARGV.first.to_i.times do
    socket << ["fooooooooo", "baaaaaar"]
    puts ">>> #{socket.receive.inspect}"
  end
end
