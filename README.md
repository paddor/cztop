[![Build Status on Travis CI](https://travis-ci.org/paddor/cztop.svg?branch=master)](https://travis-ci.org/paddor/cztop?branch=master)
[![Code Climate](https://codeclimate.com/repos/56677a7849f50a141c001784/badges/48f3cca3c62df9e4b17b/gpa.svg)](https://codeclimate.com/repos/56677a7849f50a141c001784/feed)
[![Inline docs](http://inch-ci.org/github/paddor/cztop.svg?branch=master&style=shields)](http://inch-ci.org/github/paddor/cztop)
[![Dependency Status](https://gemnasium.com/paddor/cztop.svg)](https://gemnasium.com/paddor/cztop)
[![Coverage Status](https://coveralls.io/repos/paddor/cztop/badge.svg?branch=master&service=github)](https://coveralls.io/github/paddor/cztop?branch=master)

# CZTop

```
_________  _____________________
\_   ___ \ \____    /\__    ___/____  ______
/    \  \/   /     /   |    |  /  _ \ \____ \
\     \____ /     /_   |    | (  <_> )|  |_> >
 \______  //_______ \  |____|  \____/ |   __/
        \/         \/                 |__|
```

This is CZTop, an easy-to-use CZMQ Ruby binding. It is based on
[czmq-ffi-gen](https://github.com/paddor/czmq-ffi-gen), the generated low-level FFI
binding of [CZMQ](https://github.com/zeromq/czmq).

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

## Documentation

The following API documentation is currently available:

* [YARD API documentation](http://www.rubydoc.info/github/paddor/cztop)

Feel free to start a [wiki](https://github.com/paddor/cztop/wiki) page.

## TODO

* maybe find a better name for this project
* pack generated code into its own gem (czmq-ffi-gen) [x]
* think of a neat Ruby API, including:
  - Actor [ ]
  - Socket [x]
    - Options to encapsulate all option setters and getters [ ]
    - Security mechanisms [ ]
  - Message [x]
  - Frame [x]
    - enumerable Frames [x]
  - Loop [ ]
  - Poller [ ]
  - Monitor [ ]
  - Authenticator [ ]
  - Certificate [X]
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
  - zcert.xml [x]
  - zcertstore.xml [x]

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/paddor/cztop.

To run the tests before/after you made any changes to the source and have
created a test case for it, use `rake spec`.

## License

The gem is available as open source under the terms of the [ISC License](http://opensource.org/licenses/ISC).
See the [LICENSE](https://github.com/paddor/cztop/blob/master/LICENSE) file.
