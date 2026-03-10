#!/usr/bin/env ruby
# frozen_string_literal: true

# Weather update client, based on ZMQ's zguide.
# Connects SUB socket to ipc:///tmp/weather_pubsub_example
# Collects weather updates and finds avg temp in zipcode

require "cztop"

COUNT = 100

socket = CZTop::Socket::SUB.new("ipc:///tmp/weather_pubsub_example")
puts ">>> Socket connected."

# Subscribe to zipcode. Default: 8000
filter = ARGV.first || "8000"
socket.subscribe(filter)

print "Gathering #{COUNT} samples for: #{filter.inspect}"
total_temp = 0
1.upto(COUNT) do
  zipcode, temperature, relhumidity = socket.receive.map(&:to_i)
  p(zipcode:, temperature:, relhumidity:)
  total_temp += temperature
end

puts
puts "Average temperature for zipcode #{filter} was #{total_temp / COUNT}C."
