#!/usr/bin/env ruby
#
# Weather update client, based on that from ZMQ's zguide.
# Connects SUB socket to ipc:///tmp/weather_pubsub_example
# Collects weather updates and finds avg temp in zipcode
#

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'cztop', path: '../../'
  gem 'async'
end

require 'cztop'

COUNT = 100

# Create socket, connect to publisher.
socket = CZTop::Socket::SUB.new("ipc:///tmp/weather_pubsub_example")
puts ">>> Socket Connected"

# Subscribe to zipcode.  Default: Zürich - 8000
filter = ARGV.size > 0 ? ARGV[0] : "8000"
socket.subscribe(filter)

# gather & process COUNT updates.
print "Gathering #{COUNT} samples for: #{filter.inspect}"
total_temp = 0
1.upto(COUNT) do
  zipcode, temperature, relhumidity = socket.receive.to_a.map(&:to_i)
  p(zipcode:, temperature:, relhumidity:)
	total_temp += temperature
end

puts
puts "Average temperature for zipcode #{filter} was #{total_temp / COUNT}C."
