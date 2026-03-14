#!/usr/bin/env ruby
# frozen_string_literal: true

require "cztop"

t1 = Thread.new do
  socket = CZTop::Socket::REP.new("inproc://req_rep_example")
  socket.recv_timeout = 0.05

  loop do
    msg = socket.receive
    puts "<<< #{msg.inspect}"
    socket << msg.map(&:upcase)
  rescue IO::TimeoutError
    break
  end

  puts "REP done."
end

t2 = Thread.new do
  socket = CZTop::Socket::REQ.new("inproc://req_rep_example")

  10.times do |i|
    socket << "foobar ##{i}"
    msg = socket.receive
    puts ">>> #{msg.inspect}"
  end

  puts "REQ done."
end

[t1, t2].each(&:join)
