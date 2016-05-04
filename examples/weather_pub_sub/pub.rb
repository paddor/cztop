#!/usr/bin/env ruby
#
# Weather update server, based on ZMQ's zguide.
# Binds PUB socket to ipc:///tmp/weather_pubsub_example
# Publishes random weather updates
#

require 'cztop'

# create and bind socket
socket = CZTop::Socket::PUB.new("ipc:///tmp/weather_pubsub_example")
puts "<<< Socket bound to #{socket.last_endpoint.inspect}"

while true
	# Generate values for zipcodes
	zipcode = rand(100000)
	temperature = rand(215) - 80
	relhumidity = rand(50) + 10
	
	update = "%05d %d %d" % [zipcode, temperature, relhumidity]
	puts update
	
	socket << update
end
