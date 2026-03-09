#!/usr/bin/env ruby
# frozen_string_literal: true

# This example shows how to create a simple actor using a Ruby block.
# Of course it also supports the CZMQ-native way, passing a pointer to
# a C function. That's how CZTop::Beacon, CZTop::Authenticator, ... are
# implemented.

require "cztop"

counter = 0
actor = CZTop::Actor.new do |msg, pipe|
  case command = msg[0]
  when "UPCASE"
    word = msg[1]
    puts ">>> Actor converts #{word.inspect} to uppercase."
    pipe << word.upcase
  when "COUNT"
    counter += 1
    puts ">>> Actor has incremented counter to: #{counter}"
  when "PRODUCE"
    num = msg[1].to_i
    puts ">>> Actor produces #{num} messages."
    num.times { |i| pipe << "FOO #{i + 1}/#{num}" }
  else
    raise "invalid command: #{command}"
  end
end
puts ">>> Actor created."

# Send fire-and-forget commands
6.times { actor << "COUNT" }

# Request a response
puts actor.request(["UPCASE", "foobar"]).inspect

# Let actor produce multiple messages
actor << %w[PRODUCE 5]
5.times { puts actor.receive[0] }

# Clean shutdown
actor.terminate
