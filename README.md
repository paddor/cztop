![Specs status](https://github.com/paddor/cztop/workflows/STABLE%20API/badge.svg)
![Specs status](https://github.com/paddor/cztop/workflows/DRAFT%20API%20on%20Ruby%203.3/badge.svg)
![Specs status](https://github.com/paddor/cztop/workflows/DRAFT%20API%20on%20Ruby%203.4/badge.svg)
[![codecov](https://codecov.io/gh/paddor/cztop/branch/master/graph/badge.svg?token=TnjOba97R7)](https://codecov.io/gh/paddor/cztop)

# CZTop

CZTop is a CZMQ binding for Ruby. It is based on
[czmq-ffi-gen](https://github.com/paddor/czmq-ffi-gen), the generated low-level
FFI binding of [CZMQ](https://github.com/zeromq/czmq) and has a focus on being
easy to use for Rubyists (POLS) and providing first class support for security
mechanisms (like CURVE).


## Example with Async

See [this example](https://github.com/paddor/cztop/blob/master/examples/async.rb):

```ruby
#! /usr/bin/env ruby

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'cztop', path: '../../'
  gem 'async'
end

ENDPOINT = 'inproc://req_rep_example'
# ENDPOINT = 'ipc:///tmp/req_rep_example0'
# ENDPOINT = 'tcp://localhost:5556'

Async do |task|
  rep_task = task.async do |t|
    socket = CZTop::Socket::REP.new ENDPOINT

    loop do
      msg = socket.receive
      puts "<<< #{msg.to_a.inspect}"
      socket << msg.to_a.map(&:upcase)
    end
  ensure
    puts "REP done."
  end

  task.async do
    socket = CZTop::Socket::REQ.new ENDPOINT

    10.times do |i|
      socket << "foobar ##{i}"
      msg = socket.receive
      puts ">>> #{msg.to_a.inspect}"
    end

    puts "REQ done."
    rep_task.stop
  end
end
```


Output:
```
$ cd examples
$ time ./async.rb
<<< ["foobar #0"]
>>> ["FOOBAR #0"]
<<< ["foobar #1"]
>>> ["FOOBAR #1"]
<<< ["foobar #2"]
>>> ["FOOBAR #2"]
<<< ["foobar #3"]
>>> ["FOOBAR #3"]
<<< ["foobar #4"]
>>> ["FOOBAR #4"]
<<< ["foobar #5"]
>>> ["FOOBAR #5"]
<<< ["foobar #6"]
>>> ["FOOBAR #6"]
<<< ["foobar #7"]
>>> ["FOOBAR #7"]
<<< ["foobar #8"]
>>> ["FOOBAR #8"]
<<< ["foobar #9"]
>>> ["FOOBAR #9"]
REQ done.
REP done.

________________________________________________________
Executed in  401.51 millis    fish           external
   usr time  308.44 millis  605.00 micros  307.83 millis
   sys time   40.08 millis  278.00 micros   39.81 millis

```

A slightly more complex version (more sockets) is [here](https://github.com/paddor/cztop/blob/master/examples/massive_async.rb).

## Overview

### Features

* Ruby idiomatic API
* compatible with Fiber Scheduler (only on Ruby >= 3.2)
* errors as exceptions
* CURVE security
* supports CZMQ DRAFT API
* extensive spec coverage

## Requirements


* CZMQ >= 4.2
* ZMQ >= 4.3


On Ubuntu 20.04+:

    $ sudo apt install libczmq-dev

On macOS using Homebrew, run:

    $ brew install czmq

### Supported Rubies

At least:

* Ruby 3.0, 3.1, 3.2, 3.3

## Installation

To use this gem, add this line to your application's Gemfile:

```ruby
gem 'cztop'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cztop

### Class Hierarchy

Here's an overview of the core classes:

* [CZTop](http://www.rubydoc.info/gems/cztop/CZTop)
  * [Actor](http://www.rubydoc.info/gems/cztop/CZTop)
  * [Authenticator](http://www.rubydoc.info/gems/cztop/CZTop/Authenticator)
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

## Documentation

The API should be fairly straight-forward to anyone who is familiar with CZMQ
and Ruby.  The following API documentation is currently available:

* [YARD API documentation](http://www.rubydoc.info/gems/cztop) (release)

Feel free to start a [wiki](https://github.com/paddor/cztop/wiki) page.

## Performance

CZTop is just a convenience layer on top of the thin czmq-ffi-gen library.

Make sure to check out the
[perf](https://github.com/paddor/cztop/blob/master/perf) directory for latency
and throughput measurement scripts.

## Usage

See the [examples](https://github.com/paddor/cztop/blob/master/examples) directory for some examples.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/paddor/cztop.

To run the tests before/after you made any changes to the source and have
created a test case for it, use `rake spec`.

## License

The gem is available as open source under the terms of the [ISC License](http://opensource.org/licenses/ISC).
See the [LICENSE](https://github.com/paddor/cztop/blob/master/LICENSE) file.
