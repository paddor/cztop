#!/usr/bin/env ruby
require_relative '../../lib/cztop'

##
# This example shows how to create a simple actor using a Ruby block.
# Of course it also supports the CZMQ-native way, passing a pointer to
# a C function. That's how CZTop::Beacon, CZTop::Authenticator, ... are
# implemented.
#

counter = 0
actor = CZTop::Actor.new do |msg, pipe|
  # This block is called once for every received message.

  case command = msg[0]
  when "UPCASE"
    # Upcase second message frame and send back.
    word = msg[1]
    puts ">>> Actor converts #{word.inspect} to uppercase."
    pipe << word.upcase
  when "COUNT"
    # Count up.
    counter += 1
    puts ">>> Actor has incremented counter to: #{counter}"
  when "PRODUCE"
    # Produce multiple messages.
    num = msg[1].to_i
    puts ">>> Actor produces #{num} messages."
    num.times { |i| pipe << "FOO #{i+1}/#{num}" }
  else
    # crashes actor #=> Actor#dead? and Actor#crashed? will return true
    # also, Actor#exception will return this exception.
    raise "invalid command: #{command}"
  end
end
puts ">>> Actor created."

##
# Let actor count.
#
# Actor#<< is thread-safe.
#
actor << "COUNT"
actor << "COUNT"
actor << "COUNT"
actor << "COUNT"
actor << "COUNT"
actor << "COUNT"


##
# Request a response from actor.
#
# Actor#request is thread-safe and ensures that the right response gets
# returned.
#
puts actor.request(["UPCASE", "foobar"]).inspect
#=> #<CZTop::Message:0x7f98c8d96000 frames=1 content_size=6 content=["FOOBAR"]>


##
# Let actor produce some messages.
#
# Actor#receive is thread-safe, but doesn't guarantee any particular order.
#
actor << %w[ PRODUCE 5 ]
puts actor.receive[0] #1
puts actor.receive[0] #2
puts actor.receive[0] #3
puts actor.receive[0] #4
puts actor.receive[0] #5

##
# Let actor die.
#
# Blocks until dead.
actor.terminate
actor.dead? #=> true
actor.crashed? #=> false
actor.exception #=> nil, because it didn't crash


__END__
Example output:

>>> Actor created.
>>> Actor has incremented counter to: 1
>>> Actor has incremented counter to: 2
>>> Actor has incremented counter to: 3
>>> Actor has incremented counter to: 4
>>> Actor has incremented counter to: 5
>>> Actor has incremented counter to: 6
>>> Actor converts "foobar" to uppercase.
#<CZTop::Message:0x7f81c55bdca0 frames=1 content_size=6 content=["FOOBAR"]>
>>> Actor produces 5 messages.
FOO 1/5
FOO 2/5
FOO 3/5
FOO 4/5
FOO 5/5
