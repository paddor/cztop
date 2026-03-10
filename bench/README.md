# Benchmark Results

CZMQ 4.2.1 | ZMQ 4.3.5 | Ruby 4.0.1 | Linux x86_64

## Throughput (push/pull, iterations/s)

### Async (fibers)

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 35.8k | 11.9k | 9.5k |
| 256B | 32.5k | 12.2k | 9.5k |
| 1024B | 34.5k | 11.2k | 9.6k |
| 4096B | 33.6k | 10.0k | 10.1k |

### Threads

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 40.9k | 12.4k | 10.7k |
| 256B | 39.6k | 12.1k | 10.7k |
| 1024B | 40.4k | 12.0k | 11.5k |
| 4096B | 35.8k | 12.1k | 9.5k |

## Latency (req/rep roundtrip)

### Async (fibers)

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 10.5k | 95 us |
| ipc | 4.0k | 252 us |
| tcp | 3.9k | 259 us |

### Threads

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 4.6k | 217 us |
| ipc | 3.4k | 293 us |
| tcp | 3.3k | 305 us |

## Notes

- Throughput measures one-way push/pull (no reply needed)
- Latency measures full req/rep roundtrip
- Async uses Ruby fibers via the [async](https://github.com/socketry/async) gem
- Threads use a dedicated responder thread
- Async is ~2x faster for inproc latency due to cheap fiber switching

## Running

```sh
bundle exec ruby bench/async/throughput.rb
bundle exec ruby bench/async/latency.rb
bundle exec ruby bench/threads/throughput.rb
bundle exec ruby bench/threads/latency.rb
```
