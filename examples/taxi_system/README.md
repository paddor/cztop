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

### Start broker

```
BROKER_ADDRESS=tcp://127.0.0.1:4455 BROKER_CERT=secret_keys/broker CLIENT_CERTS=public_keys/drivers ./broker.rb
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
workers = Pathname.new(client_certs).children.map(&:to_s)

authenticator = CZTop::Authenticator.new
authenticator.verbose!
authenticator.curve(client_certs)

socket = CZTop::Socket::ROUTER.new
socket.make_secure_server(broker_cert)
socket.options.router_mandatory = true # raise when message unroutable
socket.bind(endpoint)
puts "bound."

# ...
# TODO: use Monitor to wait for all drivers to connect
# in the meantime: just start client first.
sleep 5

##
# assuming all workers have connected by now
#
workers.each do |worker|
  socket.send_to(worker, "do something")
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
socket.make_secure_client(client_cert, broker_cert)
socket.connect(endpoint)
puts "connected."

while message = socket.receive
  puts "received message: #{message.to_a.inspect}"
end
```