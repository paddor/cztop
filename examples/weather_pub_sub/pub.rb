#!/usr/bin/env ruby
#
# Weather update server, based on ZMQ's zguide.
# Binds PUB socket to ipc:///tmp/weather_pubsub_example
# Publishes random weather updates
#

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'cztop', path: '../../'
  gem 'async'
end

require 'cztop'

# create and bind socket
socket = CZTop::Socket::PUB.new("ipc:///tmp/weather_pubsub_example")
puts "<<< Socket bound to #{socket.last_endpoint.inspect}"

while true
  zipcode     = rand(3..9) * 1000 + rand(0..99)
  temperature = rand(-15..38)
	relhumidity = rand(50) + 10

  update = [zipcode, temperature, relhumidity]
	puts("%04d %d %d" % update)

  socket << update.map(&:to_s)
end
