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

socket = CZTop::Socket::ROUTER.new
socket.make_secure_server(broker_cert)
socket.options.router_mandatory = true # raise when message unroutable
socket.bind(endpoint)
puts "bound."

# wait for all drivers to connect
monitor = CZTop::Monitor.new(socket)
monitor.listen("ACCEPTED")
monitor.start
monitor.actor.options.rcvtimeo = 5000
remaining = drivers.size
begin
  while event = monitor.next
    remaining -= 1 if event[0] == "ACCEPTED"
    break if remaining == 0
  end
rescue Interrupt
  abort "drivers didn't connect in time."
else
  warn "all drivers connected"
  sleep 0.1 # give ZAP some time to authenticate them
end

drivers.each do |driver|
  warn "sending message to driver: #{driver.inspect}"
  socket << [ driver, "pick customer up at X" ]
end

# TODO:
# * provide REPL to simulate customer requests and interact with the drivers
# * heartbeating
