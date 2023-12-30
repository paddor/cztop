#! /usr/bin/env ruby

require 'cztop/async'

Async do |task|
  task.async do |t|
    socket = CZTop::Socket::REP.new("ipc:///tmp/req_rep_example")

    # Simply echo every message, with every frame String#upcase'd.
    socket.options.rcvtimeo = 3
    io = Async::IO.try_convert socket

    msg = io.receive
    puts "<<< #{msg.to_a.inspect}"
    io << msg.to_a.map(&:upcase)

    puts "REP done."
  end

  task.async do
    socket = CZTop::Socket::REQ.new("ipc:///tmp/req_rep_example")
    puts ">>> Socket connected."

    io = Async::IO.try_convert socket
    # sleep 5
    io << "foobar"

    socket.options.rcvtimeo = 3
    msg = io.receive
    puts ">>> #{msg.to_a.inspect}"
    puts "REQ done."
  end

  task.async do
    6.times do
      sleep 0.5
      puts "tick"
    end
  end
end
