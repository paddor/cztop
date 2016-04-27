#!/usr/bin/env ruby
#
# Weather update client, based on that from ZMQ's zguide.
# Connects SUB socket to ipc:///tmp/weather_pubsub_example
# Collects weather updates and finds avg temp in zipcode
#

require 'cztop'

COUNT = 100

# Create socket, connect to publisher.
socket = CZTop::Socket::SUB.new("ipc:///tmp/weather_pubsub_example")
puts ">>> Socket Connected"

# Subscribe to zipcode.  Default: Chicago - 60606
filter = ARGV.size > 0 ? ARGV[0] : "60606"
socket.subscribe(filter)

# gather & process COUNT updates.
print "Gathering #{COUNT} samples."
total_temp = 0
1.upto(COUNT) do |update_nbr|
	msg = socket.receive
	
	zipcode, temperature, relhumidity = msg[0].split.map(&:to_i)
	total_temp += temperature
	# just to show that we're doing something...
	print "." if update_nbr % 5 == 0
end
print "\n"

puts "Average temperatuer for zipcode #{filter} was #{total_temp / COUNT}F."
