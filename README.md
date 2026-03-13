# CZTop

[![CI](https://github.com/paddor/cztop/actions/workflows/ci.yml/badge.svg)](https://github.com/paddor/cztop/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/cztop?color=e9573f)](https://rubygems.org/gems/cztop)
[![License: ISC](https://img.shields.io/badge/License-ISC-blue.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.3-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org)

Ruby FFI binding for [CZMQ](http://czmq.zeromq.org/) / [ZeroMQ](https://zeromq.org/) — high-performance asynchronous messaging for distributed systems.

> **353k msg/s** inproc throughput | **49 µs** fiber roundtrip latency | nonblock fast path

---

## Highlights

- **All socket types** — req/rep, pub/sub, push/pull, dealer/router, xpub/xsub, pair, stream
- **Async-first** — first-class [async](https://github.com/socketry/async) fiber support, also works with plain threads
- **Ruby-idiomatic API** — messages as `Array<String>`, errors as exceptions, timeouts as `IO::TimeoutError`

## Install

Install CZMQ on your system:

```sh
# Debian/Ubuntu
sudo apt install libczmq-dev

# macOS
brew install czmq
```

Then add the gem:

```sh
gem install cztop
# or in Gemfile
gem 'cztop'
```

## Quick Start

### Request / Reply

```ruby
require 'cztop'
require 'async'

Async do |task|
  rep = CZTop::Socket::REP.new('inproc://example')
  req = CZTop::Socket::REQ.new('inproc://example')

  task.async do
    msg = rep.receive
    rep << msg.map(&:upcase)
  end

  req << 'hello'
  puts req.receive.inspect  # => ["HELLO"]
end
```

### Pub / Sub

```ruby
Async do |task|
  pub = CZTop::Socket::PUB.new('inproc://pubsub')
  sub = CZTop::Socket::SUB.new('inproc://pubsub')
  sub.subscribe('')  # subscribe to all

  sleep 0.01  # allow connection to establish

  task.async { pub << 'news flash' }
  puts sub.receive.inspect  # => ["news flash"]
end
```

### Push / Pull (Pipeline)

```ruby
Async do
  push = CZTop::Socket::PUSH.new('inproc://pipeline')
  pull = CZTop::Socket::PULL.new('inproc://pipeline')

  push << 'work item'
  puts pull.receive.inspect  # => ["work item"]
end
```

## Socket Types

| Pattern | Classes | Direction |
|---------|---------|-----------|
| Request/Reply | `REQ`, `REP` | bidirectional |
| Publish/Subscribe | `PUB`, `SUB`, `XPUB`, `XSUB` | unidirectional |
| Pipeline | `PUSH`, `PULL` | unidirectional |
| Routing | `DEALER`, `ROUTER` | bidirectional |
| Exclusive pair | `PAIR` | bidirectional |
| Raw TCP | `STREAM` | bidirectional |

All classes live under `CZTop::Socket::`.

## Performance

Benchmarked with benchmark-ips on Linux x86_64 (CZMQ 4.2.1, ZMQ 4.3.5, Ruby 4.0.1 +YJIT):

#### Throughput (push/pull)

| | inproc | ipc | tcp |
|---|--------|-----|-----|
| **Async** | 284k/s | 17k/s | 14k/s |
| **Threads** | 353k/s | 25k/s | 21k/s |

#### Latency (req/rep roundtrip)

| | inproc | ipc | tcp |
|---|--------|-----|-----|
| **Async** | 49 µs | 100 µs | 107 µs |
| **Threads** | 113 µs | 154 µs | 168 µs |

Async fibers deliver 2.3x lower inproc latency thanks to cheap context switching. See [`bench/`](bench/) for full results and scripts.

## API Reference

Full [API documentation](http://www.rubydoc.info/gems/cztop).

## Development

```sh
bundle install
bundle exec rake
```

## License

[ISC](LICENSE)
