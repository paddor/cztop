#! /usr/bin/env ruby

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'cztop', path: '../../'
end

require 'cztop'

t1 = Thread.new do
  socket = CZTop::Socket::REP.new("inproc://req_rep_example")
  socket.options.rcvtimeo = 50 # ms

  loop do
    msg = socket.receive
    puts "<<< #{msg.to_a.inspect}"
    socket << msg.to_a.map(&:upcase)
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
    puts ">>> #{msg.to_a.inspect}"
  end

  puts "REQ done."
end

[t1, t2].each(&:join)
