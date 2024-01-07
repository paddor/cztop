#!/usr/bin/env ruby

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'cztop', path: '../../'
  gem 'pry'
end

require 'pry'
require 'pathname'
require 'cztop'

CZTop::Certificate.check_curve_availability or abort

endpoint = ENV["BROKER_ADDRESS"]
broker_cert = CZTop::Certificate.load ENV["BROKER_CERT"] # secret+public
client_certs = ENV["CLIENT_CERTS"] # /path/to/client_certs/
drivers = Pathname.new(client_certs).children.map(&:basename).map(&:to_s)

authenticator = CZTop::Authenticator.new
authenticator.verbose!
authenticator.curve(client_certs)

# create and bind socket
@socket = CZTop::Socket::SERVER.new
@socket.CURVE_server!(broker_cert)
#socket.options.sndtimeo = 0
@socket.options.heartbeat_ivl     = 100#ms
@socket.options.heartbeat_timeout = 300#ms
@socket.bind(endpoint)

puts ">>> Socket bound to #{endpoint.inspect}"

# get and print socket events
Thread.new do
  monitor = CZTop::Monitor.new(@socket)
  monitor.listen("ALL")
  monitor.start
  while msg = monitor.next
    puts ">>> Socket event: #{msg.inspect}"
  end
end

# receive messages from drivers
@driver_map = {} # driver name => routing ID
Thread.new do

  poller = CZTop::Poller.new(@socket)
  while true
    puts "waiting for socket to become readable ..."
    socket = poller.simple_wait
    puts "socket is readable"
    msg = socket.receive
    puts "got message"
    command, argument = msg[0].split("\t", 2)

    case command
    when "HELLO"
      driver = argument
      puts ">>> Driver #{driver.inspect} has connected."
      welcome = @driver_map.key?(driver) ? "WELCOMEBACK" : "WELCOME"

      # remember driver's assigned message routing ID
      @driver_map[driver] = msg.routing_id

      # send WELCOME or WELCOMEBACK
      rep = CZTop::Message.new(welcome)
      rep.routing_id = @driver_map[driver]
      socket << rep
      puts ">>> Sent #{welcome.inspect} to #{driver.inspect}"
    end
  end
end

def send_command(driver, command)
  if command.nil? || command.empty?
    puts "!!! No message given."
    return
  end
  if not @driver_map.key?(driver)
    puts "!!! Driver #{driver.inspect} has never connected."
    return
  end
  puts ">>> Sending message to #{driver.inspect} ..."
  msg = CZTop::Message.new(command)
  msg.routing_id = @driver_map[driver]
  @socket << msg
rescue SocketError
  puts "!!! Driver #{driver.inspect} isn't connected anymore."
end

##
# REPL for user to play
#
puts <<MSG
You can now send messages to the drivers yourself.
Use the method #send_command, like this:

pry> send_command("driver1", "PICKUP\t(8.541694,47.376887)")

This should show something like this in the client.rb terminal:

  03:17:01 driver1.1 | received message: "PICKUP\t(8.541694,47.376887)"
MSG

binding.pry
