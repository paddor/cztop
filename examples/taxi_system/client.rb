#!/usr/bin/env ruby
require_relative '../../lib/cztop'

endpoint = ENV["BROKER_ADDRESS"]
broker_cert = CZTop::Certificate.load ENV["BROKER_CERT"] # public only
client_cert = CZTop::Certificate.load ENV["CLIENT_CERT"]

socket = CZTop::Socket::DEALER.new
socket.options.identity = client_cert["driver_name"]
puts "set socket identity to: %p" % client_cert["driver_name"]
socket.CURVE_client!(client_cert, broker_cert)
socket.connect(endpoint)
puts "connected."

while message = socket.receive
  puts "received message: #{message.to_a.inspect}"
end
