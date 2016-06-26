# CZTop

CZTop is a CZMQ binding for Ruby. It is based on
[czmq-ffi-gen](https://github.com/paddor/czmq-ffi-gen), the generated low-level
FFI binding of [CZMQ](https://github.com/zeromq/czmq) and has a focus on being
easy to use for Rubyists (POLS) and providing first class support for security
mechanisms (like CURVE).

[![Build Status on Travis CI](https://travis-ci.org/paddor/cztop.svg?branch=master)](https://travis-ci.org/paddor/cztop?branch=master)
[![Code Climate](https://codeclimate.com/repos/56677a7849f50a141c001784/badges/48f3cca3c62df9e4b17b/gpa.svg)](https://codeclimate.com/repos/56677a7849f50a141c001784/feed)
[![Inline docs](http://inch-ci.org/github/paddor/cztop.svg?branch=master&style=shields)](http://inch-ci.org/github/paddor/cztop)
[![Dependency Status](https://gemnasium.com/paddor/cztop.svg)](https://gemnasium.com/paddor/cztop)
[![Coverage Status](https://coveralls.io/repos/paddor/cztop/badge.svg?branch=master&service=github)](https://coveralls.io/github/paddor/cztop?branch=master)
[![ISC License](https://img.shields.io/badge/license-ISC_License-blue.svg)](LICENSE)

## Reasons

Why another CZMQ Ruby binding? Here is a list of existing projects I found and
the issues with them, from my point of view:

* [Asmod4n/ruby-ffi-czmq](https://github.com/Asmod4n/ruby-ffi-czmq)
  * outdated
  * according to its author, it's an "abomination"
* [methodmissing/rbczmq](https://github.com/methodmissing/rbczmq)
  * no support for security features (see [methodmissing/rbczmq#28](https://github.com/methodmissing/rbczmq/issues/28))
  * no JRuby support (see [methodmissing/rbczmq#48](https://github.com/methodmissing/rbczmq/issues/48))
  * doesn't feel like Ruby
* [mtortonesi/ruby-czmq](https://github.com/mtortonesi/ruby-czmq)
  * no tests
  * no documentation
  * outdated
  * doesn't feel like Ruby
* [chuckremes/ffi-rzmq](https://github.com/chuckremes/ffi-rzmq)
  * support discontinued
  * low level ZMQ gem, not CZMQ

Furthermore, I knew about the generated low-level Ruby FFI binding in the
[zeromq/czmq](https://github.com/zeromq/czmq) repository. I wanted to make use
of it because I love that it's generated (and thus, most likely correct
and up-to-date). Unfortunately, it was in pretty bad shape and missing a few
CZMQ classes.

So I decided to improve the quality and usability of the binding and add the
missing classes. The result is
[czmq-ffi-gen](https://github.com/paddor/czmq-ffi-gen) which provides a solid
foundation for CZTop.

## Goals

Here are some some of the goals I have/had in mind for this library:

- [x] as easy as possible, Ruby-esque API
- [x] first class support for security (CURVE mechanism)
  - [x] including handling of certificates
- [x] support MRI, Rubinius, and JRuby
- [x] high-quality API documentation
- [x] 100% test coverage
- [x] provide a portable Z85 implementation
  * unlike [fpesce/z85](https://github.com/fpesce/z85), which is a C extension
- [x] use it to replace the [Celluloid::ZMQ](https://github.com/celluloid/celluloid-zmq) part of [Celluloid](https://github.com/celluloid/celluloid)
  * [celluloid/celluloid-zmq#56](https://github.com/celluloid/celluloid-zmq/issues/56)
- [ ] implement some of the missing (CZMQ based) Ruby examples in the [ZMQ Guide](http://zguide.zeromq.org/page:all)

## Overview

### Class Hierarchy

Here's an overview of the core classes:

* [CZTop](http://www.rubydoc.info/gems/cztop/CZTop)
  * [Actor](http://www.rubydoc.info/gems/cztop/CZTop)
  * [Authentiator](http://www.rubydoc.info/gems/cztop/CZTop/Authenticator) < Actor
  * [Beacon](http://www.rubydoc.info/gems/cztop/CZTop/Beacon) < Actor
  * [Certificate](http://www.rubydoc.info/gems/cztop/CZTop/Certificate)
  * [Config](http://www.rubydoc.info/gems/cztop/CZTop/Config)
  * [Frame](http://www.rubydoc.info/gems/cztop/CZTop/Frame)
  * [Message](http://www.rubydoc.info/gems/cztop/CZTop/Message)
  * [Monitor](http://www.rubydoc.info/gems/cztop/CZTop/Monitor) < Actor
  * [Proxy](http://www.rubydoc.info/gems/cztop/CZTop/Proxy) < Actor
  * [Poller](http://www.rubydoc.info/gems/cztop/CZTop/Poller)
    * [Aggregated](http://www.rubydoc.info/gems/cztop/CZTop/Poller/Aggregated)
  * [Socket](http://www.rubydoc.info/gems/cztop/CZTop/Socket)
    * [REQ](http://www.rubydoc.info/gems/cztop/CZTop/Socket/REQ) < Socket
    * [REP](http://www.rubydoc.info/gems/cztop/CZTop/Socket/REP) < Socket
    * [ROUTER](http://www.rubydoc.info/gems/cztop/CZTop/Socket/ROUTER) < Socket
    * [DEALER](http://www.rubydoc.info/gems/cztop/CZTop/Socket/DEALER) < Socket
    * [PUSH](http://www.rubydoc.info/gems/cztop/CZTop/Socket/PUSH) < Socket
    * [PULL](http://www.rubydoc.info/gems/cztop/CZTop/Socket/PULL) < Socket
    * [PUB](http://www.rubydoc.info/gems/cztop/CZTop/Socket/PUB) < Socket
    * [SUB](http://www.rubydoc.info/gems/cztop/CZTop/Socket/SUB) < Socket
    * [XPUB](http://www.rubydoc.info/gems/cztop/CZTop/Socket/XPUB) < Socket
    * [XSUB](http://www.rubydoc.info/gems/cztop/CZTop/Socket/XSUB) < Socket
    * [PAIR](http://www.rubydoc.info/gems/cztop/CZTop/Socket/PAIR) < Socket
    * [STREAM](http://www.rubydoc.info/gems/cztop/CZTop/Socket/STREAM) < Socket
    * [CLIENT](http://www.rubydoc.info/gems/cztop/CZTop/Socket/CLIENT) < Socket
    * [SERVER](http://www.rubydoc.info/gems/cztop/CZTop/Socket/SERVER) < Socket
  * [Z85](http://www.rubydoc.info/gems/cztop/CZTop/Z85)
    * [Padded](http://www.rubydoc.info/gems/cztop/CZTop/Z85/Padded) < Z85
    * [Pipe](http://www.rubydoc.info/gems/cztop/CZTop/Z85/Pipe)

More information in the [API documentation](http://www.rubydoc.info/github/paddor/cztop).

### Features

* Ruby-like API
  * method names
    * sending a message via a socket is done with `Socket#<<`
      * `socket << "simple message"`
      * `socket << ["multi", "frame", "message"]`
    * `#x=` methods instead of `#set_x` (e.g. socket options)
    * `#[]` where it makes sense (e.g. on a Message, Config, or Certificate)
  * no manual error checking needed
    * if there's an error, an appropriate exception is raised
  * of course, no manual dealing with the ZMQ context
* easy security
  * use `Socket#CURVE_server!(cert)` on the server
  * and `Socket#CURVE_client!(client_cert, server_cert)` on the client
* socket types as Ruby classes
  * no need to manually pass some constant
    * but you can: `CZTop::Socket.new_by_type(:REP)`
  * e.g. `#subscribe` only exists on CZTop::Socket::SUB
* SERVER and CLIENT ready
  * see CZTop::Socket::SERVER and CZTop::Socket::CLIENT
  * there are `#routing_id` and `#routing_id=` on the following classes:
    * CZTop::Message
    * CZTop::Frame
* ZMTP 3.1 heartbeat ready
  * `socket.options.heartbeat_ivl = 2000`
  * `socket.options.heartbeat_timeout = 8000`

## Requirements

You'll need:

* CZMQ > 3.0.2 (currently built from master)
* ZMQ >= 4.2 (currently built from master)

For security mechanisms like CURVE, you'll need:

* [libsodium](https://github.com/jedisct1/libsodium)

To install on OSX using homebrew, run:

    $ brew install libsodium
    $ brew install zmq  --HEAD --with-libsodium
    $ brew install czmq --HEAD

If you're running Linux, go check [this page](http://zeromq.org/distro:_start)
to get more help. Make sure to install CZMQ, not only ZMQ.

**Note:** Currently (as of May 2016), when compiling ZMQ from master, it may
be required to pass `--enable-drafts` to `./configure` to make sure all the
`zmq_poller_*()` functions are available. However, this doesn't seem to be the
case on all systems.

### Supported Ruby versions

See [.travis.yml](https://github.com/paddor/cztop/blob/master/.travis.yml) for a list of Ruby versions against which CZTop
is tested.

At the time of writing, these include:

* MRI (2.3, 2.2)
* Rubinius (HEAD)
* JRuby 9000 (HEAD)

## Installation

To use this gem, add this line to your application's Gemfile:

```ruby
gem 'cztop'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cztop

## Documentation

The API should be fairly straight-forward to anyone who is familiar with CZMQ
and Ruby.  The following API documentation is currently available:

* [YARD API documentation](http://www.rubydoc.info/github/paddor/cztop) (HEAD)
* [YARD API documentation](http://www.rubydoc.info/gems/cztop) (release)

Feel free to start a [wiki](https://github.com/paddor/cztop/wiki) page.

## Performance

Performance should be pretty okay since this is based on czmq-ffi-gen, which is
reasonably thin.  CZTop is basically only a convenience layer on top, with some
nice error checking. But hey, it's Ruby. Don't expect 5M messages per second
with a latency of 3us.

The measured latency on my laptop ranges from ~20us to ~60us per message for
1kb messages, depending on whether transport is inproc, IPC, or TCP/IP.

Make sure you check out the
[perf](https://github.com/paddor/cztop/blob/master/perf) directory for latency
and throughput measurement scripts.

## Usage

See the [examples](https://github.com/paddor/cztop/blob/master/examples) directory for some examples. Here's a very simple one:

### rep.rb:

```ruby
#!/usr/bin/env ruby
require 'cztop'

# create and bind socket
socket = CZTop::Socket::REP.new("ipc:///tmp/req_rep_example")
puts "<<< Socket bound to #{socket.last_endpoint.inspect}"

# Simply echo every message, with every frame String#upcase'd.
while msg = socket.receive
  puts "<<< #{msg.to_a.inspect}"
  socket << msg.to_a.map(&:upcase)
end
```

### req.rb:

```ruby
#!/usr/bin/env ruby
require 'cztop'

# connect
socket = CZTop::Socket::REQ.new("ipc:///tmp/req_rep_example")
puts ">>> Socket connected."

# simple string
socket << "foobar"
msg = socket.receive
puts ">>> #{msg.to_a.inspect}"

# multi frame message as array
socket << %w[foo bar baz]
msg = socket.receive
puts ">>> #{msg.to_a.inspect}"

# manually instantiating a Message
msg = CZTop::Message.new("bla")
msg << "another frame" # append a frame
socket << msg
msg = socket.receive
puts ">>> #{msg.to_a.inspect}"

##
# This will send 20 additional messages:
#
#   $ ./req.rb 20
#
if ARGV.first
  ARGV.first.to_i.times do
    socket << ["fooooooooo", "baaaaaar"]
    puts ">>> " + socket.receive.to_a.inspect
  end
end
```

### Running it

```
$ ./rep.rb & ./req.rb 3
[3] 35321
>>> Socket connected.
<<< Socket bound to "ipc:///tmp/req_rep_example"
<<< ["foobar"]
>>> ["FOOBAR"]
<<< ["foo", "bar", "baz"]
>>> ["FOO", "BAR", "BAZ"]
<<< ["bla", "another frame"]
>>> ["BLA", "ANOTHER FRAME"]
<<< ["fooooooooo", "baaaaaar"]
>>> ["FOOOOOOOOO", "BAAAAAAR"]
<<< ["fooooooooo", "baaaaaar"]
>>> ["FOOOOOOOOO", "BAAAAAAR"]
<<< ["fooooooooo", "baaaaaar"]
>>> ["FOOOOOOOOO", "BAAAAAAR"]
$
```

## TODO

* [x] pack generated code into its own gem ([czmq-ffi-gen](https://github.com/paddor/czmq-ffi-gen))
* think of a neat Ruby API, including:
  - [x] Actor
  - [x] Beacon
  - [x] Certificate
  - [x] Socket
    - [50%] access to all socket options
    - [x] Security mechanisms
  - [x] Message
  - [x] Frame
    - [x] enumerable Frames
  - [x] Authenticator
  - [x] Loop
  - [x] Monitor
  - [x] Poller
  - [x] Proxy
  - [x] Config
  - [x] Z85
* write the missing XML API files in CZMQ
  - [x] zarmour.xml
  - [x] zconfig.xml
  - [x] zsock_option.xml
  - [x] zcert.xml
  - [x] zcertstore.xml
* [x] check availability of libsodium within CZTop
* [x] read error strings for exceptions where appropriate (zmq_strerror)
* [x] add support for ZMTP 3.1 heartbeats in CZMQ
* [x] add padded variant of Z85
* add more examples
  * [x] [simple REQ/REP](https://github.com/paddor/cztop/tree/master/examples/simple_req_rep)
  * [x] [Taxy System](https://github.com/paddor/cztop/tree/master/examples/taxi_system) with CURVE security and heartbeating
    * [x] change from ROUTER/DEALER to SERVER/CLIENT
  * [x] [Actor](https://github.com/paddor/cztop/tree/master/examples/ruby_actor) with Ruby block
  * [ ] PUSH/PULL
  * [ ] PUB/SUB
* [ ] add performance benchmarks
  * [x] inproc latency
  * [x] inproc throughput
  * [x] local/remote latency
  * [ ] local/remote throughput
  * see [perf](https://github.com/paddor/cztop/blob/master/perf) directory
* [x] support older versions of ZMQ
  * [x] ZMQ HEAD
    * [x] tested on CI
  * [x] ZMQ 4.1
    * [x] tested on CI
    * as of April 2016, this isn't the case anymore
  * [x] ZMQ 4.0
    * [x] tested on CI
    * as of March 2016, this isn't the case anymore
  * [ ] ZMQ 3.2
    * too big a pain ([d5172ab](https://github.com/paddor/czmq-ffi-gen/commit/d5172ab6db64999c50ba24f71569acf1dd45af51))
* [x] support multiple versions of CZMQ
  * [x] CZMQ HEAD
    * [x] test on CI
  * [x] CZMQ 3.0.2 (current stable)
    * no `zcert_meta_unset()` ([zeromq/czmq#1246](https://github.com/zeromq/czmq/issues/1246))
      * [x] adapt czmq-ffi-gen so it doesn't raise while `attach_function`
    * no `zproc`(especially no `zproc_has_curve()`)
      * [x] adapt czmq-ffi-gen so it doesn't raise while `attach_function`, attach `zsys_has_curve()` instead (under same name)
    * [x] adapt test suite to skip affected test examples
    * [x] test on CI
    * as of March, 2016, this isn't the case anymore
* [x] port [Poller](http://www.rubydoc.info/gems/cztop/CZTop/Poller) to `zmq_poll()`
  * backwards compatible (`#add_reader`, `#add_writer`, `#wait` behave the same)
  * but in addition, it has `#readables` and `#writables` which return arrays of sockets
  * could then be used in Celluloid::ZMQ
* [ ] add `Message#to_s`
  * return frame as string, if there's only one frame
  * raise if there are multiple frames
  * only safe to use on messages from SERVER/CLIENT sockets
  * single-part messages are the future
  * not sure yet
* [x] get rid of Loop
  * cannot handle CLIENT/SERVER sockets
  * there good timer gems for Ruby
  * Poller can be used to embed in an existing event loop (Celluloid), or make your own trivial one
* [x] provide `z85encode` and `z85decode` utilities
  * can be used in a pipeline (limited memory usage)
  * reusable interface: `Z85::Pipe`


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/paddor/cztop.

To run the tests before/after you made any changes to the source and have
created a test case for it, use `rake spec`.

## License

The gem is available as open source under the terms of the [ISC License](http://opensource.org/licenses/ISC).
See the [LICENSE](https://github.com/paddor/cztop/blob/master/LICENSE) file.
