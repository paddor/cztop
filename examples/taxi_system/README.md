# Taxi System

Suppose you're running a taxi company ("cabs"). You have a set of taxi drivers
working for you.  You'd like to connect them to your central server, so they're
ready to get service requests from customers who'd like to get picked up by a
taxi from some place X. As soon as a customer sends his service request, the
central server will send the closest taxi nearby that's available to the
customer.

Of course you want the communication between the broker and the taxi drivers to
be secure, meaning you want encryption and authentication.

You also want ping-pong heartbeating, as you want to have confidence you can
get in touch with your taxi drivers any time you want. (TODO: not implemented yet)

## Broker

Here's a possible implementation of the broker. What you'll have to provide
are the environment variables `BROKER_ADDRESS` (the public TCP endpoint),
`BROKER_CERT` (path to the broker's secret+public keys), and `CLIENT_CERTS`
(directory to taxi drivers' certificates, public keys only).

```ruby
#!/usr/bin/env ruby
require 'pathname'
require_relative '../../lib/cztop'

endpoint = ENV["BROKER_ADDRESS"]
broker_cert = CZTop::Certificate.load ENV["BROKER_CERT"] # secret+public
client_certs = ENV["CLIENT_CERTS"] # /path/to/client_certs/
drivers = Pathname.new(client_certs).children.map(&:basename).map(&:to_s)

authenticator = CZTop::Authenticator.new
authenticator.verbose!
authenticator.curve(client_certs)

socket = CZTop::Socket::ROUTER.new
socket.CURVE_server!(broker_cert)
socket.options.router_mandatory = true # raise when message unroutable
socket.bind(endpoint)
puts "bound."

# wait for all drivers to connect
monitor = CZTop::Monitor.new(socket)
monitor.listen("ACCEPTED")
monitor.start
monitor.actor.options.rcvtimeo = 5000
remaining = drivers.size
begin
  while event = monitor.next
    remaining -= 1 if event[0] == "ACCEPTED"
    break if remaining == 0
  end
rescue Interrupt
  abort "drivers didn't connect in time."
else
  warn "all drivers connected"
  sleep 0.1 # give ZAP some time to authenticate them
end

drivers.each do |driver|
  warn "sending message to driver: #{driver.inspect}"
  socket << [ driver, "pick customer up at X" ]
end

# TODO:
# * provide REPL to simulate customer requests and interact with the drivers
# * heartbeating
```

## Client

Here you have to provide the environment variables `BROKER_ADDRESS` (ditto),
`BROKER_CERT` (public key only), `CLIENT_CERT` (taxi driver's certificate
containing the secret+public keys).

```ruby
#!/usr/bin/env ruby
puts "bla"
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
  msg.pop # remove delimiter frame
  puts "received message: #{message.to_a.inspect}"
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
require_relative '../../lib/cztop'
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

### Start driver software instances

To avoid the tedious task of starting multiple driver software instances in
different terminals, a simple foreman Procfile is provided to conveniently
start them all at once.
Run `gem install foreman` if you don't have it yet.

Starting it is simple:

```
foreman start
```

### Start broker

When starting the broker, it'll initially wait for 3 clients to connect before
sending any commands, otherwise sending an unroutable message would raise an
exception (because ROUTER_MANDATORY is set to true). In practice, this
wouldn't be necessary. If a driver, who's on duty, you want to send a command
to (like "pickup someone from X") cannot be contacted, something's bad and you
want to know about it.

After the clients are connected (and authenticated), each one of them is sent
a small message to simulate a command being sent to them. You'll see these pop
up in the first terminal where you started the driver software.

```
BROKER_ADDRESS=tcp://127.0.0.1:4455 BROKER_CERT=secret_keys/broker CLIENT_CERTS=public_keys/drivers ./broker.rb
```

