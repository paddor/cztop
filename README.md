# CZTop

CZTop is a CZMQ binding for Ruby. It is based on
[czmq-ffi-gen](https://gitlab.com/paddor/czmq-ffi-gen), the generated low-level
FFI binding of [CZMQ](https://github.com/zeromq/czmq) and has a focus on being
easy to use for Rubyists (POLS) and providing first class support for security
mechanisms (like CURVE).

[![pipeline status](https://gitlab.com/paddor/cztop/badges/master/pipeline.svg)](https://gitlab.com/paddor/cztop/commits/master)
[![Coverage Status](https://coveralls.io/repos/gitlab/paddor/cztop/badge.svg?branch=master)](https://coveralls.io/gitlab/paddor/cztop?branch=master)
[![ISC License](https://img.shields.io/badge/license-ISC_License-blue.svg)](LICENSE)

## Goals

Here are some some of the goals I had in mind for this library:

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
  * [Authentiator](http://www.rubydoc.info/gems/cztop/CZTop/Authenticator)
  * [Beacon](http://www.rubydoc.info/gems/cztop/CZTop/Beacon)
  * [Certificate](http://www.rubydoc.info/gems/cztop/CZTop/Certificate)
  * [CertStore](http://www.rubydoc.info/gems/cztop/CZTop/CertStore)
  * [Config](http://www.rubydoc.info/gems/cztop/CZTop/Config)
  * [Frame](http://www.rubydoc.info/gems/cztop/CZTop/Frame)
  * [Message](http://www.rubydoc.info/gems/cztop/CZTop/Message)
  * [Monitor](http://www.rubydoc.info/gems/cztop/CZTop/Monitor)
  * [Metadata](http://www.rubydoc.info/gems/cztop/CZTop/Metadata)
  * [Proxy](http://www.rubydoc.info/gems/cztop/CZTop/Proxy)
  * [Poller](http://www.rubydoc.info/gems/cztop/CZTop/Poller) (based on `zmq_poller_*()` functions)
    * [Aggregated](http://www.rubydoc.info/gems/cztop/CZTop/Poller/Aggregated)
    * [ZPoller](http://www.rubydoc.info/gems/cztop/CZTop/Poller/ZPoller)
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
    * [RADIO](http://www.rubydoc.info/gems/cztop/CZTop/Socket/RADIO) < Socket
    * [DISH](http://www.rubydoc.info/gems/cztop/CZTop/Socket/DISH) < Socket
    * [SCATTER](http://www.rubydoc.info/gems/cztop/CZTop/Socket/SCATTER) < Socket
    * [GATHER](http://www.rubydoc.info/gems/cztop/CZTop/Socket/GATHER) < Socket
  * [Z85](http://www.rubydoc.info/gems/cztop/CZTop/Z85)
    * [Padded](http://www.rubydoc.info/gems/cztop/CZTop/Z85/Padded) < Z85
    * [Pipe](http://www.rubydoc.info/gems/cztop/CZTop/Z85/Pipe)
  * [ZAP](http://www.rubydoc.info/gems/cztop/CZTop/ZAP)

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
* DRAFT API ready
  * certain DRAFT methods are supported if the libraries (ZMQ/CZMQ) have been compiled with DRAFT APIs enabled (`--enable-drafts`)
  * use `CZMQ::FFI.has_draft?` to check if the CZMQ DRAFT API is available
  * use `CZMQ::FFI::LibZMQ.has_draft?` to check if the ZMQ DRAFT API is available
  * extend CZTop to your needs
* ZMTP 3.1 heartbeat ready
  * `socket.options.heartbeat_ivl = 2000`
  * `socket.options.heartbeat_timeout = 8000`

## Requirements

You'll need:

* CZMQ >= 4.1
* ZMQ >= 4.2

For security mechanisms like CURVE, it's recommended to use Libsodium. However,
ZMQ can be compiled with tweetnacl enabled.

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

* [YARD API documentation](http://www.rubydoc.info/gems/cztop) (release)

Feel free to start a [wiki](https://gitlab.com/paddor/cztop/wiki) page.

## Performance

Performance should be pretty okay since this is based on czmq-ffi-gen, which is
reasonably thin.  CZTop is just a convenience layer.

Make sure to check out the
[perf](https://gitlab.com/paddor/cztop/blob/master/perf) directory for latency
and throughput measurement scripts.

## Usage

See the [examples](https://gitlab.com/paddor/cztop/blob/master/examples) directory for some examples.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/paddor/cztop.

To run the tests before/after you made any changes to the source and have
created a test case for it, use `rake spec`.

## License

The gem is available as open source under the terms of the [ISC License](http://opensource.org/licenses/ISC).
See the [LICENSE](https://github.com/paddor/cztop/blob/master/LICENSE) file.
