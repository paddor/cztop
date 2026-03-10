#!/usr/bin/env ruby
# frozen_string_literal: true

require "cztop"
require "async"

ENDPOINT = "inproc://req_rep_example"

Async do |task|
  rep_task = task.async do
    socket = CZTop::Socket::REP.new(ENDPOINT)

    loop do
      msg = socket.receive
      puts "<<< #{msg.inspect}"
      socket << msg.map(&:upcase)
    end
  ensure
    puts "REP done."
  end

  task.async do
    socket = CZTop::Socket::REQ.new(ENDPOINT)

    10.times do |i|
      socket << "foobar ##{i}"
      msg = socket.receive
      puts ">>> #{msg.inspect}"
    end

    puts "REQ done."
    rep_task.stop
  end
end
