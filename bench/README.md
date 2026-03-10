# Benchmark Results

CZMQ 4.2.1 | ZMQ 4.3.5 | Ruby 4.0.1 | Linux x86_64

## Throughput (push/pull, iterations/s)

### Async (fibers)

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 36.1k | 12.0k | 10.5k |
| 256B | 37.7k | 12.7k | 10.4k |
| 1024B | 34.0k | 12.4k | 10.4k |
| 4096B | 34.6k | 11.3k | 10.2k |

### Threads

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 41.1k | 12.6k | 10.9k |
| 256B | 38.1k | 12.5k | 10.7k |
| 1024B | 38.6k | 12.3k | 10.6k |
| 4096B | 35.4k | 11.9k | 10.6k |

## Latency (req/rep roundtrip)

### Async (fibers)

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 11.3k | 89 µs |
| ipc | 6.4k | 156 µs |
| tcp | 5.4k | 185 µs |

### Threads

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 5.7k | 177 µs |
| ipc | 4.8k | 209 µs |
| tcp | 4.6k | 218 µs |

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
