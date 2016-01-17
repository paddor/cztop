#!/usr/bin/env ruby
require_relative '../../lib/cztop'

# connect
socket = CZTop::Socket::REQ.new("ipc:///tmp/req_rep_example")
puts ">>> Socket connected."

# simple string
socket << "foobar"
msg = socket.receive
puts ">>> #{msg.to_a.inspect}"

# multi frame message as array
socket << %w[foo bar baz]
msg = socket.receive
puts ">>> #{msg.to_a.inspect}"

# manually instantiating a Message
msg = CZTop::Message.new("bla")
msg << "another frame" # append a frame
socket << msg
msg = socket.receive
puts ">>> #{msg.to_a.inspect}"

##
# This will send 20 additional messages:
#
#   ./req.rb 20
#
if ARGV.first
  ARGV.first.to_i.times do
    socket << ["fooooooooo", "baaaaaar"]
    puts ">>> " + socket.receive.to_a.inspect
  end
end
