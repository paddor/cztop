# CZTop

Ruby FFI binding for CZMQ/ZMQ. Version 2.0.0.pre1. Requires Ruby >= 3.3.

## Architecture

- `lib/cztop/socket.rb` — Socket base class (connect, bind, CURVE, etc.)
- `lib/cztop/socket/fd_wait.rb` — `FdWait` mixin: FD polling infrastructure (`FD_TIMEOUT`, `JIFFY`, `#wait_for_fd_signal`, `#wait_for_socket_state`)
- `lib/cztop/socket/readable.rb` — `Readable` mixin: `#receive` → `Array<String>`, `#wait_readable`, `#read_timeout`
- `lib/cztop/socket/writable.rb` — `Writable` mixin: `#send` accepts `String`/`Array<String>`, `#<<`, `#wait_writable`, `#write_timeout`
- `lib/cztop/socket/types.rb` — `Types` constants + `TypeNames`
- `lib/cztop/socket/{req,rep,dealer,router,pub,sub,xpub,xsub,push,pull,pair,stream}.rb` — individual socket types
- `lib/cztop/ffi.rb` — FFI bindings + CZMQ signal handler disabling
- `bench/` — benchmark-ips scripts (async/threads × throughput/latency)

### ZMQ FD polling

ZMQ uses a single edge-triggered FD for both read/write signaling. `#wait_for_socket_state`
checks socket readiness first (fast path via `#readable?`/`#writable?`), then polls the FD.

- `FD_TIMEOUT` (250ms) — max time in `IO#wait_readable` per loop iteration; safety net for missed edges
- `JIFFY` (1ms) — sleep after false wakeup (FD signals but socket not ready)
- Edge misses are rare (~0.2% of calls in ipc/tcp req/rep), never in inproc throughput
- `IO#wait_readable` is interruptible by signals — Ctrl-C works immediately
- `__send__` used instead of `send` to avoid clash with ZMQ `#send` method
- Socket types include only the mixins they need (e.g. PUB includes only Writable, SUB only Readable)

### Tuning rationale

- JIFFY 15ms→1ms: each edge miss stalls for full JIFFY duration; 1ms reduces impact 15x
- FD_TIMEOUT 500ms→250ms: halves worst-case stall; no measurable perf impact since FD signals correctly 99.8% of the time
- Measured with `bench/jiffy_sweep.rb`, `bench/fd_timeout_sweep.rb`, `bench/edge_miss_count.rb`

## Benchmarking

- Uses benchmark-ips with `warmup: 1, time: 3`
- Run benchmarks sequentially to reduce variance
- For parameter sweeps: test multiple values in a single script with 3 runs each, report median
- Sister project **rbnng** (`/home/roadster/dev/oss/rbnng`) has identical bench structure for comparison
