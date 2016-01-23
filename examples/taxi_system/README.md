# Taxi System

Suppose you're running a taxi company. You have a set of taxi drivers
working for you.  You'd like to connect them to your central server, so they're
ready to get service requests from customers who'd like to get picked up by a
taxi from some place X. As soon as a customer sends his service request, the
central server will send the closest taxi nearby that's available to the
customer.

Of course you want the communication between the broker and the taxi drivers to
be secure, meaning you want encryption and authentication.

You also want ping-pong heartbeating, as you want to have confidence you can
get in touch with your taxi drivers any time you want. And if a service
request can't be delivered to a particular taxi driver, you wanna know
immediately.

This solution is implemented using CLIENT/SERVER sockets and the CURVE
security mechanism.

## Broker

Here's a possible implementation of the broker. What you'll have to provide
are the environment variables `BROKER_ADDRESS` (the public TCP endpoint),
`BROKER_CERT` (path to the broker's secret+public keys), and `CLIENT_CERTS`
(directory to taxi drivers' certificates, public keys only).

After the start, the broker will just start listening for the drivers (CLIENT
sockets) to connect. After a driver has connected, authenticated, and sent its
`HELLO` message, the broker answers with a `WELCOME` or `WELCOMEBACK` message,
depending if the driver was connected before (it might have reconnected and
been assigned a new routing ID).

The broker will present you with a Pry shell. Right before starting the shell,
there's a small usage information, but it's not very well visible due to Pry's
noisy start. It's simple, though. Inside that shell, you can use the method
`#send_command(driver, command)`. Example:

```
  pry> send_command("driver1", "foobar")
```

Depending on whether the driver is connected, it'll send the message or report
that it cannot do so.

```ruby
#!/usr/bin/env ruby
require 'pry'
require 'pathname'
require 'cztop'

endpoint = ENV["BROKER_ADDRESS"]
broker_cert = CZTop::Certificate.load ENV["BROKER_CERT"] # secret+public
client_certs = ENV["CLIENT_CERTS"] # /path/to/client_certs/
drivers = Pathname.new(client_certs).children.map(&:basename).map(&:to_s)

authenticator = CZTop::Authenticator.new
authenticator.verbose!
authenticator.curve(client_certs)

# create and bind socket
@socket = CZTop::Socket::SERVER.new
@socket.CURVE_server!(broker_cert)
#socket.options.sndtimeo = 0
@socket.options.heartbeat_ivl     = 100#ms
@socket.options.heartbeat_timeout = 300#ms
@socket.bind(endpoint)

puts ">>> Socket bound to #{endpoint.inspect}"

# get and print socket events
Thread.new do
  monitor = CZTop::Monitor.new(@socket)
  monitor.listen("ALL")
  monitor.start
  while msg = monitor.next
    puts ">>> Socket event: #{msg.inspect}"
  end
end

# receive messages from drivers
@driver_map = {} # driver name => routing ID
Thread.new do

  # CZTop::Loop (zloop) doesn't work with SERVER sockets :(
  poller = CZTop::Poller.new(@socket)
  while true
    puts "waiting for socket to become readable ..."
    socket = poller.wait
    puts "socket is readable"
    msg = socket.receive
    puts "got message"
    command, argument = msg[0].split("\t", 2)

    case command
    when "HELLO"
      driver = argument
      puts ">>> Driver #{driver.inspect} has connected."
      welcome = @driver_map.key?(driver) ? "WELCOMEBACK" : "WELCOME"

      # remember driver's assigned message routing ID
      @driver_map[driver] = msg.routing_id

      # send WELCOME or WELCOMEBACK
      rep = CZTop::Message.new(welcome)
      rep.routing_id = @driver_map[driver]
      socket << rep
      puts ">>> Sent #{welcome.inspect} to #{driver.inspect}"
    end
  end
end

def send_command(driver, command)
  if command.nil? || command.empty?
    puts "!!! No message given."
    return
  end
  if not @driver_map.key?(driver)
    puts "!!! Driver #{driver.inspect} has never connected."
    return
  end
  puts ">>> Sending message to #{driver.inspect} ..."
  msg = CZTop::Message.new(command)
  msg.routing_id = @driver_map[driver]
  @socket << msg
rescue SocketError
  puts "!!! Driver #{driver.inspect} isn't connected anymore."
end

##
# REPL for user to play
#
puts <<MSG
You can now send messages to the drivers yourself.
The use the method #send_command, like this:

pry> send_command("driver1", "PICKUP\t(8.541694,47.376887)")

This should show something like this in the client.rb terminal:

  03:17:01 driver1.1 | received message: "PICKUP\t(8.541694,47.376887)"
MSG

binding.pry
```

## Client

Here you have to provide the environment variables `BROKER_ADDRESS` (ditto),
`BROKER_CERT` (public key only), `CLIENT_CERT` (taxi driver's certificate
containing the secret+public keys).

After connecting to the broker and completing the security handshake, the
client sends a `HELLO` message, after which it immediately expects some answer
from the broker (see above). After that, it just listens for messages (service
requests) and prints them into the terminal.

```ruby
#!/usr/bin/env ruby
require 'cztop'

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
  socket = poller.wait
  message = socket.receive
  puts ">>> received message: #{message[0].inspect}"
end
```

## How to run the example

### Generate broker's and drivers' keys

Here's a simple script that'll create the broker's certificate and the taxi
drivers' certificates. There are also public key only files so a minimum amount
of information can be made available on one system, e.g. a taxi driver's system
must not know the broker's secret key. Also, the broker doesn't necessarily
need to know the clients' secret keys just to authenticate them.

```ruby
#!/usr/bin/env ruby
require 'cztop'
require 'fileutils'
FileUtils.cd(File.dirname(__FILE__))
FileUtils.mkdir "public_keys"
FileUtils.mkdir "public_keys/drivers"
FileUtils.mkdir "secret_keys"
FileUtils.mkdir "secret_keys/drivers"
#FileUtils.mkdir "certs/drivers"

DRIVERS = %w[ driver1 driver2 driver3 ]

# broker certificate
cert = CZTop::Certificate.new
cert.save("secret_keys/broker")
cert.save_public("public_keys/broker")

# driver certificates
DRIVERS.each do |driver_name|
  cert = CZTop::Certificate.new
  cert["driver_name"] = driver_name
  cert.save "secret_keys/drivers/#{driver_name}"
  cert.save_public "public_keys/drivers/#{driver_name}"
end

```
Run it as follows:

```
./generate_keys.rb
```

### Start broker

Run this:

```
./start_broker.sh
```

which will execute the following script:

```sh
#!/bin/sh -x
BROKER_ADDRESS=tcp://127.0.0.1:4455 BROKER_CERT=secret_keys/broker CLIENT_CERTS=public_keys/drivers ./broker.rb
```

### Start driver software instances

Run this in another terminal:

```
./start_clients.sh
```

which will execute the following script:

```sh
#!/bin/sh -x
export BROKER_ADDRESS=tcp://127.0.0.1:4455
export BROKER_CERT=public_keys/broker
CLIENT_CERT=secret_keys/drivers/driver1_secret ./client.rb &
CLIENT_CERT=secret_keys/drivers/driver2_secret ./client.rb &
CLIENT_CERT=secret_keys/drivers/driver3_secret ./client.rb &
jobs
jobs -p
jobs -l
trap 'kill $(jobs -p)' EXIT
wait
```

