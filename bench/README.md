# Benchmarks

Measured on October 11, 2026 with CZMQ 4.2.1, ZMQ 4.3.5, Ruby 4.0.6 +YJIT,
FFI 1.17.3, Async 2.38.1, and benchmark-ips 2.14.0. Linux x86_64, KVM guest
with six vCPUs on an Intel Core i7-8700B at 3.20 GHz.

Each case uses one second of warmup and three seconds of measurement.
Scripts ran serially. These are single-run results; throughput variation
reported by benchmark-ips ranged from 0.5% to 4.3%.

## Throughput

PUSH/PULL messages per second. Each iteration sends one string and receives
one message, on the same thread or fiber. There is no separate receiver
worker, so this measures consecutive send/receive calls rather than a
saturated pipeline.

### Async

| Payload | inproc | ipc | tcp |
|---------|--------|-----|-----|
| 64 B | 278.1k | 18.3k | 15.8k |
| 256 B | 278.2k | 18.0k | 15.3k |
| 1024 B | 252.4k | 17.5k | 15.2k |
| 4096 B | 202.1k | 16.1k | 14.8k |

### Threads

| Payload | inproc | ipc | tcp |
|---------|--------|-----|-----|
| 64 B | 309.6k | 18.3k | 16.2k |
| 256 B | 302.9k | 17.9k | 15.9k |
| 1024 B | 270.6k | 17.5k | 15.4k |
| 4096 B | 238.3k | 16.7k | 15.1k |

## Latency

REQ/REP roundtrip with a four-byte request echoed by a separate responder
thread or Async task. Latency is the reciprocal of measured roundtrips per
second, rather than a per-message percentile.

| Mode | Transport | Roundtrips/s | Roundtrip latency |
|------|-----------|--------------|-------------------|
| Async | inproc | 16.5k | 60.7 µs |
| Async | ipc | 8.9k | 112.6 µs |
| Async | tcp | 7.8k | 127.8 µs |
| Threads | inproc | 13.4k | 74.9 µs |
| Threads | ipc | 9.2k | 109.2 µs |
| Threads | tcp | 8.4k | 119.6 µs |

## CURVE

PUSH/PULL messages per second over loopback TCP, using consecutive
send/receive calls on one thread. Authentication and connection setup
finish before measurement.

| Payload | Plaintext | CURVE |
|---------|-----------|-------|
| 64 B | 16.7k | 16.0k |
| 256 B | 16.4k | 15.2k |
| 1024 B | 15.8k | 14.6k |
| 4096 B | 15.7k | 13.2k |

## Running

Run each command separately:

```sh
bundle exec ruby --yjit -W:no-experimental bench/async/throughput.rb
bundle exec ruby --yjit -W:no-experimental bench/async/latency.rb
bundle exec ruby --yjit bench/threads/throughput.rb
bundle exec ruby --yjit bench/threads/latency.rb
bundle exec ruby --yjit bench/threads/curve_throughput.rb
```

`-W:no-experimental` suppresses Ruby's IO::Buffer experimental warning from
Async's stdout handling. Other warning categories remain enabled.

Sockets close after each case. IPC uses a temporary directory; TCP uses
an OS-selected port. The send/receive fast paths use `zframe_recv_nowait`
and `zframe_send` with `ZFRAME_DONTWAIT`, then wait on the ZMQ file descriptor
when the socket would block.
