[![CI](https://github.com/paddor/cztop/actions/workflows/ci.yml/badge.svg)](https://github.com/paddor/cztop/actions/workflows/ci.yml)

# CZTop

CZTop is a CZMQ binding for Ruby with handcrafted FFI bindings. It focuses on
being easy to use for Rubyists (POLS) and provides first-class support for
security mechanisms (CURVE).

## Features

* Ruby-idiomatic API
* Fiber Scheduler compatible
* errors as exceptions
* CURVE security
* extensive test coverage

## Requirements

* CZMQ >= 4.2
* ZMQ >= 4.3
* Ruby 3.3+

### Installing dependencies

Ubuntu 20.04+:

    $ sudo apt install libczmq-dev

macOS (Homebrew):

    $ brew install czmq

## Installation

Add to your Gemfile:

```ruby
gem 'cztop'
```

Then run `bundle install`. Or install directly:

    $ gem install cztop

## Quick example

```ruby
require 'cztop'
require 'async'

ENDPOINT = 'inproc://req_rep_example'

Async do |task|
  rep_task = task.async do
    socket = CZTop::Socket::REP.new(ENDPOINT)

    loop do
      msg = socket.receive
      puts "<<< #{msg.to_a.inspect}"
      socket << msg.to_a.map(&:upcase)
    end
  ensure
    puts "REP done."
  end

  task.async do
    socket = CZTop::Socket::REQ.new(ENDPOINT)

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

More examples in the [examples](https://github.com/paddor/cztop/tree/master/examples) directory.

## Class overview

* [CZTop](http://www.rubydoc.info/gems/cztop/CZTop)
  * [Actor](http://www.rubydoc.info/gems/cztop/CZTop/Actor)
  * [Authenticator](http://www.rubydoc.info/gems/cztop/CZTop/Authenticator)
  * [Beacon](http://www.rubydoc.info/gems/cztop/CZTop/Beacon)
  * [Certificate](http://www.rubydoc.info/gems/cztop/CZTop/Certificate)
  * [CertStore](http://www.rubydoc.info/gems/cztop/CZTop/CertStore)
  * [Config](http://www.rubydoc.info/gems/cztop/CZTop/Config)
  * [Frame](http://www.rubydoc.info/gems/cztop/CZTop/Frame)
  * [Message](http://www.rubydoc.info/gems/cztop/CZTop/Message)
  * [Metadata](http://www.rubydoc.info/gems/cztop/CZTop/Metadata)
  * [Monitor](http://www.rubydoc.info/gems/cztop/CZTop/Monitor)
  * [Proxy](http://www.rubydoc.info/gems/cztop/CZTop/Proxy)
  * [Socket](http://www.rubydoc.info/gems/cztop/CZTop/Socket)
    * [REQ](http://www.rubydoc.info/gems/cztop/CZTop/Socket/REQ), [REP](http://www.rubydoc.info/gems/cztop/CZTop/Socket/REP), [ROUTER](http://www.rubydoc.info/gems/cztop/CZTop/Socket/ROUTER), [DEALER](http://www.rubydoc.info/gems/cztop/CZTop/Socket/DEALER)
    * [PUB](http://www.rubydoc.info/gems/cztop/CZTop/Socket/PUB), [SUB](http://www.rubydoc.info/gems/cztop/CZTop/Socket/SUB), [XPUB](http://www.rubydoc.info/gems/cztop/CZTop/Socket/XPUB), [XSUB](http://www.rubydoc.info/gems/cztop/CZTop/Socket/XSUB)
    * [PUSH](http://www.rubydoc.info/gems/cztop/CZTop/Socket/PUSH), [PULL](http://www.rubydoc.info/gems/cztop/CZTop/Socket/PULL)
    * [PAIR](http://www.rubydoc.info/gems/cztop/CZTop/Socket/PAIR), [STREAM](http://www.rubydoc.info/gems/cztop/CZTop/Socket/STREAM)
  * [Z85](http://www.rubydoc.info/gems/cztop/CZTop/Z85)
  * [ZAP](http://www.rubydoc.info/gems/cztop/CZTop/ZAP)

Full [API documentation](http://www.rubydoc.info/gems/cztop).

## Performance

CZTop is a thin convenience layer on top of CZMQ via FFI. See the
[perf](https://github.com/paddor/cztop/tree/master/perf) directory for
latency and throughput measurement scripts.

## Contributing

Bug reports and pull requests are welcome at https://github.com/paddor/cztop.

Run the tests with `bundle exec rake`.

## License

Available as open source under the [ISC License](http://opensource.org/licenses/ISC).
See the [LICENSE](https://github.com/paddor/cztop/blob/master/LICENSE) file.
