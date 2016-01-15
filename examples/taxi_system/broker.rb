#!/usr/bin/env ruby
require 'pathname'
require_relative '../../lib/cztop'

endpoint = ENV["BROKER_ADDRESS"]
broker_cert = CZTop::Certificate.load ENV["BROKER_CERT"] # secret+public
client_certs = ENV["CLIENT_CERTS"] # /path/to/client_certs/
drivers = Pathname.new(client_certs).children.map(&:basename).map(&:to_s)

authenticator = CZTop::Authenticator.new
authenticator.verbose!
authenticator.curve(client_certs)

# create and bind socket
socket = CZTop::Socket::ROUTER.new
socket.CURVE_server!(broker_cert)
socket.options.router_mandatory = true # raise when message unroutable
socket.bind(endpoint)
socket.options.heartbeat_ivl = 100#ms # send PING every 100ms
socket.options.heartbeat_ttl = 320#ms # close connection after 320ms of no life sign
socket.options.heartbeat_timeout = 220#ms # close connection after 220ms of no life sign

# FIXME: heartbeating seems broken. Wireshark doesn't show any PING/PONG, nor
# does the monitor deliver a DISCONNECTED event. Also, sending a message to
# a driver who was connected (but not anymore), will result in a hang (instead
# of Errno::EHOSTUNREACH). :-(

puts ">>> Socket bound to #{endpoint.inspect}"

# wait for all drivers to connect
monitor = CZTop::Monitor.new(socket)
monitor.listen(:ALL)
monitor.start
monitor.actor.options.rcvtimeo = 5000
remaining = drivers.size
begin
  puts ">>> Waiting for drivers to connect ..."
  while event = monitor.next
    puts event.inspect
    remaining -= 1 if event[0] == "ACCEPTED"
    break if remaining == 0
  end
rescue IO::EAGAINWaitReadable
  abort "!!! drivers didn't connect in time."
else
  puts ">>> All drivers have connected"
  sleep 0.1 # give ZAP some time to authenticate them
end

# get and print later socket events
Thread.new do
  while msg = monitor.receive
    puts ">>> Socket event: #{msg.inspect}"
  end
end

# send each driver a example message
drivers.each do |driver|
  puts ">>> Sending message to #{driver.inspect}"
  socket << [ driver, "PICKUP", "(X,Y)" ]
end

##
# REPL for user to play
#
puts <<MSG
You can now send messages to the drivers yourself.
The command format is:

  $ <receiver> <message>

Tabs in <message> are treated as message frame separators.

Example:

  $ driver1 PICKUP\t(8.541694,47.376887)

This should show something like this in the client.rb terminal:

  03:17:01 driver1.1 | received message: ["PICKUP", "(8.541694,47.376887)"]

MSG

loop do
  print "$ "
  receiver, command = STDIN.gets.chomp.split(" ", 2)
  redo if receiver.nil? || receiver.empty?
  if command.nil?
    puts "!!! No message given."
    redo
  end
  puts ">>> Sending message to #{receiver.inspect} ..."
  begin
    socket << [ receiver, *command.split("\t") ]
  rescue Errno::EHOSTUNREACH
    puts "!!! Driver #{receiver.inspect} isn't connected. Typo?"
  end
end
