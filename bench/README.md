# Benchmark Results

CZMQ 4.2.1 | ZMQ 4.3.5 | Ruby 4.0.1 | Linux x86_64

## Throughput (push/pull, iterations/s)

### Async (fibers)

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 36.9k | 12.3k | 10.0k |
| 256B | 37.5k | 12.5k | 10.2k |
| 1024B | 35.2k | 12.0k | 10.1k |
| 4096B | 33.5k | 11.2k | 10.0k |

### Threads

| Size | inproc | ipc | tcp |
|------|--------|-----|-----|
| 64B | 34.6k | 12.1k | 10.4k |
| 256B | 36.7k | 12.0k | 10.5k |
| 1024B | 34.9k | 11.7k | 10.5k |
| 4096B | 31.6k | 11.5k | 10.2k |

## Latency (req/rep roundtrip)

### Async (fibers)

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 12.2k | 82 us |
| ipc | 6.8k | 148 us |
| tcp | 5.5k | 182 us |

### Threads

| Transport | roundtrips/s | latency |
|-----------|-------------|---------|
| inproc | 6.1k | 163 us |
| ipc | 5.1k | 196 us |
| tcp | 4.9k | 203 us |

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
