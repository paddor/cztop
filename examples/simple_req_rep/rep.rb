#!/usr/bin/env ruby
require 'cztop'

# create and bind socket
socket = CZTop::Socket::REP.new("ipc:///tmp/req_rep_example")
puts "<<< Socket bound to #{socket.last_endpoint.inspect}"

# Simply echo every message, with every frame String#upcase'd.
while msg = socket.receive
  puts "<<< #{msg.to_a.inspect}"
  socket << msg.to_a.map(&:upcase)
end
