#!/usr/bin/env ruby

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'cztop', path: '../../'
end

require 'cztop'

CZTop::Certificate.check_curve_availability or abort

endpoint = ENV["BROKER_ADDRESS"]
broker_cert = CZTop::Certificate.load ENV["BROKER_CERT"] # public only
client_cert = CZTop::Certificate.load ENV["CLIENT_CERT"]

@socket = CZTop::Socket::CLIENT.new
@socket.CURVE_client!(client_cert, broker_cert)
@socket.options.sndtimeo     = 2000#ms

# heartbeating:
# * send PING every 100ms
# * close connection after 300ms of no life sign from broker
# * tell broker to close connection after 500ms of no life sign from client
@socket.options.heartbeat_ivl     = 100#ms
@socket.options.heartbeat_timeout = 300#ms
@socket.options.heartbeat_ttl     = 500#ms

@socket.connect(endpoint)
puts ">>> connected."

# tell broker who we are
@socket << "HELLO\t#{client_cert["driver_name"]}"
puts ">>> sent HELLO."
welcome = @socket.receive[0]
puts ">>> got #{welcome}."

poller = CZTop::Poller.new(@socket)
while true
  socket = poller.simple_wait
  message = socket.receive
  puts ">>> received message: #{message[0].inspect}"
end
