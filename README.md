[![Build Status on Travis CI](https://travis-ci.org/paddor/cztop.svg?branch=master)](https://travis-ci.org/paddor/cztop?branch=master)

# CZTop

This is a CZMQ Ruby binding, based on the generated low-level FFI bindings of
the [CZMQ](https://github.com/zeromq/czmq) project.

## Reasons

* low-level FFI bindings of [zeromq/czmq](https://github.com/zeromq/czmq)
  * I love the idea because they're generated
  * but they were in a very bad state (much better now, of course)
* [Asmod4n/ruby-ffi-czmq](https://github.com/Asmod4n/ruby-ffi-czmq)
  * outdated
  * according to its author, it's an "abomination"
* [methodmissing/rbczmq](https://github.com/methodmissing/rbczmq)
  * no JRuby support (see [methodmissing/rbczmq#48](https://github.com/methodmissing/rbczmq/issues/48))
  * no support for security features (see [methodmissing/rbczmq#28](https://github.com/methodmissing/rbczmq/issues/28))
* [mtortonesi/ruby-czmq](https://github.com/mtortonesi/ruby-czmq)
  * no tests
  * outdated
* [chuckremes/ffi-rzmq](https://github.com/chuckremes/ffi-rzmq)
  * low level ZMQ gem, not CZMQ

## Goals

Here are some some of the goals I have in mind for this library:

* as easy as possible API
* first class support for security (CURVE mechanism)
  * including handling of certificates
* support MRI, Rubinius, and JRuby
* use it to replace the Celluloid::ZMQ part of Celluloid
* being able to implement some of the missing (CZMQ based) Ruby examples in the ZMQ Guide
* provide a portable Z85 implementation
  * unlike [fpesce/z85](https://github.com/fpesce/z85), which is a C extension

Possibly in another project, which will use this one:

* being able to make well-designed reliability patterns from ZMQ Guide ready to use
  - ping-pong (a la http://zguide.zeromq.org/page:all#Heartbeating-for-Paranoid-Pirate)
  - Majordomo
  - Freelance
  - (TODO: have a closer look at Malamute/MLDP)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cztop'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cztop

## Usage

Suppose you have a set of devices (workers) and you want to connect them to
your central server (broker), so they're ready to get tasks to assigned to them
(to specific workers) and complete them. You could do something like this, as
`worker.rb`:

```ruby
#!/usr/bin/env ruby
# worker.rb

config = CZTop::Config.load(ENV[:WORKER_CONFIG])
endpoint = config["broker/address"]
socket = CZTop::Socket::DEALER.new(endpoint)

while message = socket.receive
  puts "received message with #{message.size} frames"
  message.frames.each.with_index do |frame, i|
    puts "frame #%i: %p" % [ i, frame.to_s ]
  end
end

# TODO:
# * describe security
#   - loading broker's public key (CZTop::Certificate)
#   - loading client's certificate (CZTop::Certificate)
```

```ruby
#!/usr/bin/env ruby
# server.rb

config = CZTop::Config.load(ENV[:BROKER_CONFIG])
endpoint = config["broker/address"]
socket = CZTop::Socket::ROUTER.new(endpoint)

# ...

##
# assuming all workers have connected by now
#
config["workers"].direct_children.each do |worker|
  message = CZTop::Message.new([ worker.name, "", "take a break"])
  socket << message
end

# TODO:
# * describe security
#   - loading broker's certificate (CZTop::Certificate)
#   - allowing all client public keys from a directory (CZTop::CertificateStore)
# * nicer way to send a message to a specific worker
#   - CZTop::Socket::ROUTER#send_to(receiver, message)
```

## TODO

* maybe find a better name for this project
* think of a neat Ruby API, including:
  - Actor [ ]
  - Socket [x]
    - Options to encapsulate all option setters and getters [ ]
    - Security mechanisms [ ]
  - Message [x]
  - Frame [x]
    - enumerable Frames [x]
  - Loop [ ]
  - Authenticator [ ]
  - Certificate [ ]
  - CertificateStore [ ]
  - Config [x]
  - Proxy [ ]
  - Z85 [x]
  - Beacon [x]
* specify runnable specs
  - lot of outlining already done
* write the missing XML API files in CZMQ
  - zarmour.xml [x]
  - zconfig.xml [x]
  - zsock_option.xml [x]
  - zcert.xml [ ]
  - zcertstore.xml [ ]

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/paddor/cztop.

To run the tests before/after you made any changes to the source and have
created a test case for it, use `rake spec`.

## License

The gem is available as open source under the terms of the [ISC License](http://opensource.org/licenses/ISC).
See the LICENSE file.
