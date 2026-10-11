# CZTop

[![CI](https://github.com/paddor/cztop/actions/workflows/ci.yml/badge.svg)](https://github.com/paddor/cztop/actions/workflows/ci.yml)
[![Gem Version](https://img.shields.io/gem/v/cztop?color=e9573f)](https://rubygems.org/gems/cztop)
[![License: ISC](https://img.shields.io/badge/License-ISC-blue.svg)](LICENSE)
[![Ruby](https://img.shields.io/badge/Ruby-%3E%3D%203.3-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org)

Ruby FFI binding for [CZMQ](https://github.com/zeromq/czmq) and [ZeroMQ](https://zeromq.org/), with support for threads, Fiber Scheduler, and CURVE encryption.

> **310k msg/s** inproc throughput (64 B) | **61 µs** Async roundtrip latency

---

## Highlights

- **Socket types:** REQ/REP, PUB/SUB, PUSH/PULL, DEALER/ROUTER, XPUB/XSUB, PAIR, STREAM
- **Fibers and threads:** works with [async](https://github.com/socketry/async) and plain threads
- **Ruby API:** messages as `Array<String>`, errors as exceptions, timeouts as `IO::TimeoutError`

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
```

Or add it to your Gemfile:

```ruby
gem 'cztop'
```

## Learning ZeroMQ

New to ZeroMQ? See [ZGUIDE_SUMMARY.md](ZGUIDE_SUMMARY.md) for messaging patterns and working CZTop examples.

## Quick Start

### REQ / REP

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

### PUB / SUB

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

### PUSH / PULL (Pipeline)

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
| Publish/Subscribe | `PUB`, `SUB` | unidirectional |
| Subscription forwarding | `XPUB`, `XSUB` | bidirectional |
| Pipeline | `PUSH`, `PULL` | unidirectional |
| Routing | `DEALER`, `ROUTER` | bidirectional |
| Exclusive pair | `PAIR` | bidirectional |
| Raw TCP | `STREAM` | bidirectional |

All classes live under `CZTop::Socket::`.

## Performance

Benchmarked with benchmark-ips on Linux x86_64 (CZMQ 4.2.1, ZMQ 4.3.5, Ruby 4.0.6 +YJIT):

#### Throughput (PUSH/PULL, 64 B messages)

| | inproc | ipc | tcp |
|---|--------|-----|-----|
| **Async** | 278k/s | 18.3k/s | 15.8k/s |
| **Threads** | 310k/s | 18.3k/s | 16.2k/s |

#### Latency (REQ/REP roundtrip)

| | inproc | ipc | tcp |
|---|--------|-----|-----|
| **Async** | 60.7 µs | 112.6 µs | 127.8 µs |
| **Threads** | 74.9 µs | 109.2 µs | 119.6 µs |

See [bench/README.md](bench/README.md) for full results, measurement details, and scripts.

## API Reference

Full [API documentation](http://www.rubydoc.info/gems/cztop).

## Development

```sh
bundle install
bundle exec rake
```

## License

[ISC](LICENSE)
