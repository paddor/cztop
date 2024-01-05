#! /usr/bin/env ruby

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'cztop', path: '../../'
  gem 'async'
  gem 'async-io'
end

require 'cztop/async'

Async do |task|
  task.async do |t|
    socket = CZTop::Socket::REP.new("inproc://req_rep_example")
    io     = Async::IO.try_convert socket

    socket.options.rcvtimeo = 50 # ms

    loop do
      msg = io.receive
      puts "<<< #{msg.to_a.inspect}"
      io << msg.to_a.map(&:upcase)
    rescue IO::TimeoutError
      break
    end

    puts "REP done."
  end

  task.async do
    socket = CZTop::Socket::REQ.new("inproc://req_rep_example")
    io     = Async::IO.try_convert socket

    10.times do |i|
      io << "foobar ##{i}"
      msg = io.receive
      puts ">>> #{msg.to_a.inspect}"
    end

    puts "REQ done."
  end
end
