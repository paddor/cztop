# Benchmark Results

CZMQ 4.2.1 | ZMQ 4.3.5 | Ruby 4.0.1+YJIT | Linux x86_64

## Throughput (push/pull, iterations/s)

### Async (fibers)

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 283.6k | 17.3k | 11.4k |
| 256B | 292.0k | 17.1k | 18.6k |
| 1024B | 251.7k | 16.7k | 13.9k |
| 4096B | 204.2k | 17.3k | 13.9k |

### Threads

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 353.0k | 26.5k | 22.5k |
| 256B | 341.6k | 23.7k | 21.3k |
| 1024B | 303.8k | 24.4k | 20.8k |
| 4096B | 242.3k | 22.8k | 20.4k |

## Latency (req/rep roundtrip)

### Async (fibers)

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 20.3k | 49 µs |
| ipc | 10.0k | 100 µs |
| tcp | 9.3k | 107 µs |

### Threads

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 8.8k | 113 µs |
| ipc | 6.5k | 154 µs |
| tcp | 5.9k | 168 µs |

## Notes

- Throughput measures one-way push/pull (no reply needed)
- Latency measures full req/rep roundtrip
- Send/receive uses a nonblocking fast path via `zframe_recv_nowait`/`zframe_send(DONTWAIT)`, falling back to FD polling when data isn't immediately available
- Async uses Ruby fibers via the [async](https://github.com/socketry/async) gem
- Threads use a dedicated responder thread
- Async is ~2x faster for inproc latency due to cheap fiber switching

## Running

```sh
bundle exec ruby --yjit bench/async/throughput.rb
bundle exec ruby --yjit bench/async/latency.rb
bundle exec ruby --yjit bench/threads/throughput.rb
bundle exec ruby --yjit bench/threads/latency.rb
```
