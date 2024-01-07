#! /usr/bin/env ruby

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'cztop', path: '../../'
  gem 'async'
end

ENDPOINT = 'inproc://req_rep_example'
# ENDPOINT = 'ipc:///tmp/req_rep_example0'
# ENDPOINT = 'tcp://localhost:5556'

Async do |task|
  rep_task = task.async do |t|
    socket = CZTop::Socket::REP.new ENDPOINT

    loop do
      msg = socket.receive
      puts "<<< #{msg.to_a.inspect}"
      socket << msg.to_a.map(&:upcase)
    end
  ensure
    puts "REP done."
  end

  task.async do
    socket = CZTop::Socket::REQ.new ENDPOINT

    10.times do |i|
      socket << "foobar ##{i}"
      msg = socket.receive
      puts ">>> #{msg.to_a.inspect}"
    end

    puts "REQ done."
    rep_task.stop
  end
end
