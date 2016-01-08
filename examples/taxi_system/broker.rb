#!/usr/bin/env ruby
require 'pathname'
require_relative '../../lib/cztop'

endpoint = ENV["BROKER_ADDRESS"]
broker_cert = CZTop::Certificate.load ENV["BROKER_CERT"] # secret+public
client_certs = ENV["CLIENT_CERTS"] # /path/to/client_certs/
workers = Pathname.new(client_certs).children.map(&:to_s)

authenticator = CZTop::Authenticator.new
authenticator.verbose!
authenticator.curve(client_certs)

socket = CZTop::Socket::ROUTER.new
socket.make_secure_server(broker_cert)
socket.options.router_mandatory = true # raise when message unroutable
socket.bind(endpoint)
puts "bound."

# ...
# TODO: use Monitor to wait for all drivers to connect
# in the meantime: just start client first.
sleep 5

##
# assuming all workers have connected by now
#
workers.each do |worker|
  socket.send_to(worker, "do something")
end

# TODO:
# * provide REPL to simulate customer requests and interact with the drivers
# * heartbeating
