# The ZeroMQ Guide — 30 Minute Edition

The [zguide](https://zguide.zeromq.org/) is a ~500 page book. This is
the 30-minute version — half a CS lecture — that teaches you the same
material, for the modern brain with a 12-second attention span. No
philosophical digressions, no committee design talk. Just how ZMQ works,
the patterns, and how to use them from Ruby with
[CZTop](https://github.com/paddor/cztop).

Working examples live in [`examples/zguide/`](examples/zguide/) — each
is a standalone Minitest file you can run directly.

---

## What ZeroMQ is (and isn't)

ZeroMQ is a messaging *library*, not a server. No daemon, no broker, no
config files, no JVM. You link it into your process the way you'd link
libpthread or libcurl. It gives you sockets that carry discrete *messages*
(not byte streams) over tcp, ipc, inproc (inter-thread), or pgm (multicast).

Think of it as **Berkeley sockets that understand message framing, do
async I/O in a background thread, reconnect automatically, and route
messages by pattern** — REQ/REP, PUB/SUB, PUSH/PULL, and so on.

The "zero" in ZeroMQ means zero broker, zero latency (as close as
possible), zero administration. You don't install a service; you `apt
install libczmq-dev` and start writing code.

### What it replaces

| Instead of…                   | ZeroMQ gives you…                        |
|-------------------------------|------------------------------------------|
| Raw TCP + hand-rolled framing | Length-delimited message frames           |
| RabbitMQ / Kafka / NATS       | In-process library, no broker to operate  |
| gRPC / HTTP                   | Async, pattern-based, polyglot sockets    |
| D-Bus / COM / CORBA           | Lightweight IPC without a bus daemon      |
| POSIX MQs                     | Cross-network, cross-language, multi-pattern |

### Is ZeroMQ dead?

The project is quiet. The last libzmq release was 4.3.5 (2023), CZMQ
4.2.1 (2020), and the zguide hasn't seen significant updates since
~2014. The mailing list is low-traffic. There's no commercial entity
driving development.

But "dead" and "done" are different things. The library is rock-solid,
battle-tested over 15+ years, and does exactly what it claims. The wire
protocol (ZMTP 3.1) is stable and well-specified. The patterns in the
zguide are timeless distributed systems fundamentals — they don't expire.
libzmq runs in production at scale across industries, and the API hasn't
needed to change because it got the abstractions right.

Think of it like SQLite, or zlib, or libevent — mature infrastructure
that just works. You don't need a release every quarter to trust it.

### Why not just use a broker?

Brokers are great when you actually need them — durable queues,
dead-letter handling, multi-tenant isolation. But for many use cases —
internal service communication, pipeline processing, real-time data
distribution, inter-thread coordination — a broker is overhead you're
paying for but not using. ZeroMQ gives you the messaging *primitives*
and lets you compose exactly the topology you need.

It's the difference between installing PostgreSQL when all you need is
SQLite, or deploying Kubernetes when a systemd unit file would do.

---

## What makes ZMQ sockets special

ZMQ sockets aren't BSD sockets with extra steps. They're a different
animal:

- **You never touch the network directly.** Sends queue into an
  in-process buffer; a background I/O thread handles the wire. Your
  code and the network run concurrently without you writing async code.
- **Connect/bind order doesn't matter.** You can connect before the
  remote side has bound. ZMQ queues messages and retries in the
  background. Startup order is decoupled.
- **Automatic reconnection.** If a TCP connection drops, ZMQ reconnects
  transparently. Messages sent during the window are queued. You don't
  write retry loops or handle `ECONNREFUSED`.
- **Messages, not bytes.** TCP is a byte stream. ZMQ is message-oriented
  — send a message, receive that exact message. No framing code, no
  reassembly buffers.
- **Transport-agnostic.** Switch from `tcp://` to `ipc://` to
  `inproc://` by changing the endpoint string. Same API, same patterns.
  `inproc://` gives sub-µs latency; `tcp://` gives cross-machine reach.
- **Built-in back-pressure.** Every socket has configurable high-water
  marks (default: 1000 messages). Full queue? PUB drops, PUSH blocks.
  No silent unbounded memory growth.

---

## The four core patterns

ZeroMQ's API is organized around *patterns* — predefined roles that
sockets play. Each socket type enforces a messaging discipline so you
can't accidentally send when you should receive.

### 1. REQ/REP — Request-Reply

```
  client (REQ)  ──req──▶  server (REP)
                ◀──rep──
```

Strict lockstep: send, recv, send, recv. Violating the sequence returns
an error. The socket automatically prepends/strips an empty delimiter
frame (the *envelope*) so the REP knows where to route the reply.

This is the simplest pattern and maps directly to RPC. The lockstep
enforcement means you can't accidentally pipeline requests or forget to
reply. The downside: if the server crashes after receiving but before
replying, the REQ socket is stuck in "expecting recv" state. The only
fix is to destroy it and create a new one (Lazy Pirate pattern).

```ruby
require 'cztop'

# --- server.rb ---
rep = Cztop::Socket::REP.bind('tcp://*:5555')
loop do
  msg = rep.receive            # => ["Hello"]
  rep << "World"
end

# --- client.rb ---
req = Cztop::Socket::REQ.connect('tcp://localhost:5555')
req << "Hello"
reply = req.receive            # => ["World"]
```

Scaling it up: stick a ROUTER/DEALER proxy in the middle and fan out to
N workers without changing client code.

→ see [`examples/zguide/01_req_rep.rb`](examples/zguide/01_req_rep.rb)

### 2. PUB/SUB — Publish-Subscribe

```
  publisher (PUB)  ──msg──▶  subscriber 1 (SUB)
                   ──msg──▶  subscriber 2 (SUB)
                   ──msg──▶  subscriber N (SUB)
```

PUB sends to all connected SUBs. SUB filters by topic prefix — filtering
happens on the *publisher* side (since ZMQ 3.x), so unwanted messages
don't even cross the network. In CZTop, `SUB.new` subscribes to
everything by default; pass `prefix:` to filter or `prefix: nil` to defer.

Late-joining subscribers miss earlier messages — this is by design,
like tuning into a radio station. If you need catch-up, layer a
snapshot mechanism on top (see Clone pattern below).

PUB never blocks; if a subscriber is slow, messages are dropped once the
high-water mark is hit. Adding more subscribers doesn't slow down the
publisher.

One subtle point: PUB/SUB has a **startup race**. When a SUB connects,
the subscription must propagate to the publisher. Messages published
during this brief window (µs for inproc, ms for tcp) are lost. If your
first message matters, synchronize with a REQ/REP handshake first.

```ruby
# --- publisher.rb ---
pub = Cztop::Socket::PUB.bind('tcp://*:5556')
loop do
  pub << "weather.nyc #{rand(60..100)}F"
  pub << "weather.sfo #{rand(50..80)}F"
  sleep 1
end

# --- subscriber.rb ---
sub = Cztop::Socket::SUB.connect('tcp://localhost:5556', prefix: 'weather.nyc')
loop do
  msg = sub.receive             # => ["weather.nyc 74F"]
  puts msg.first
end

# --- subscribe to everything (the default) ---
sub = Cztop::Socket::SUB.connect('tcp://localhost:5556')

# --- defer subscription, add later ---
sub = Cztop::Socket::SUB.new('tcp://localhost:5556', prefix: nil)
sub.subscribe('weather.sfo')
```

→ see [`examples/zguide/02_pub_sub.rb`](examples/zguide/02_pub_sub.rb)

### 3. PUSH/PULL — Pipeline

```
  ventilator (PUSH)  ──task──▶  worker 1 (PULL)
                     ──task──▶  worker 2 (PULL)
                     ──task──▶  worker N (PULL)
                                     │
                                   result
                                     ▼
                                sink (PULL)
```

Fan-out/fan-in. PUSH round-robins messages across connected PULLs. No
replies, no envelopes — just a unidirectional pipeline. Think of it as
`xargs -P` for network messages.

The round-robin is fair but not load-aware: fast and slow workers get
the same number of tasks. For load-aware distribution, use
ROUTER/DEALER with a "send me work when I'm ready" protocol.

Unlike PUB/SUB, PUSH/PULL provides back-pressure. If all workers are
busy and their queues are full, PUSH blocks (or times out).

```ruby
# --- ventilator.rb ---
push = Cztop::Socket::PUSH.bind('tcp://*:5557')
100.times { |i| push << "task #{i}" }

# --- worker.rb (run N of these) ---
pull = Cztop::Socket::PULL.connect('tcp://localhost:5557')
sink = Cztop::Socket::PUSH.connect('tcp://localhost:5558')
loop do
  task = pull.receive.first
  result = process(task)
  sink << result
end

# --- sink.rb ---
pull = Cztop::Socket::PULL.bind('tcp://*:5558')
loop { puts pull.receive.first }
```

→ see [`examples/zguide/03_pipeline.rb`](examples/zguide/03_pipeline.rb)

### 4. PAIR — Exclusive Pair

One-to-one, bidirectional, no routing. Designed for coordinating two
threads within a process via inproc. Not meant for network use — no
reconnection, no identity handling. A full-duplex pipe.

```ruby
a = CZTop::Socket::PAIR.new('@inproc://pipe')
b = CZTop::Socket::PAIR.new('>inproc://pipe')

a << 'ping'
b.receive      # => ["ping"]
b << 'pong'
a.receive      # => ["pong"]
```

---

## The advanced socket types

Beyond the four basic patterns, ZeroMQ provides "raw" socket types for
manual control over routing. These are the building blocks for brokers,
proxies, and custom topologies.

### ROUTER

A ROUTER socket tracks every connection with an *identity* — a binary
string that uniquely identifies each peer (auto-generated or set via
`socket.identity = 'name'`). On receive, ROUTER prepends the sender's
identity as the first frame. On send, you provide the target identity as
the first frame — ROUTER strips it and delivers to that peer.

Messages to unknown identities are **silently dropped** by default.
ROUTER is the workhorse of every broker pattern.

```ruby
router = Cztop::Socket::ROUTER.bind('tcp://*:5559')

# Receive: [client_identity, "", "Hello"]
msg = router.receive
identity = msg[0]

# Reply to that specific client
router << [identity, "", "World"]

# Or use the convenience method:
router.send_to(identity, "World")
```

### DEALER

An async REQ — round-robins outgoing messages across connections and
fair-queues incoming messages, but without the send/recv lockstep. You
can fire off 10 requests without waiting for replies. The trade-off: you
manage envelopes yourself.

```ruby
dealer = Cztop::Socket::DEALER.connect('tcp://localhost:5559')
dealer.identity = 'worker-1'

# No lockstep — send multiple requests without waiting
dealer << ["", "request 1"]
dealer << ["", "request 2"]

# Receive replies as they come
reply = dealer.receive
```

### ROUTER + DEALER = async broker

```
  clients (REQ)  ──▶  ROUTER │ proxy │ DEALER  ──▶  workers (REP)
```

ROUTER facing clients, DEALER facing workers. Messages flow through,
DEALER round-robins to workers. Clients and workers are completely
decoupled — add workers by connecting more processes, remove by killing
them. In Ruby, two threads forward in each direction:

```ruby
frontend = Cztop::Socket::ROUTER.bind('tcp://*:5559')
backend  = Cztop::Socket::DEALER.bind('tcp://*:5560')

Thread.new do
  loop do
    msg = frontend.receive
    backend << msg
  end
end

loop do
  msg = backend.receive
  frontend << msg
end
```

→ see the broker test in [`examples/zguide/01_req_rep.rb`](examples/zguide/01_req_rep.rb)

### The envelope through a ROUTER chain

Understanding frame flow through ROUTER is essential for building
brokers:

```
REQ client sends:     ["Hello"]
                      ↓  (REQ prepends empty delimiter)
On the wire:          ["", "Hello"]
                      ↓  (ROUTER prepends client identity)
ROUTER receives:      ["client-A", "", "Hello"]
                      ↓  (broker forwards to DEALER)
DEALER sends:         ["client-A", "", "Hello"]
                      ↓  (REP strips envelope, delivers payload)
REP receives:         ["Hello"]

REP sends reply:      ["World"]
                      ↓  (REP re-wraps saved envelope)
On the wire:          ["client-A", "", "World"]
                      ↓  (DEALER fair-queues to ROUTER)
ROUTER receives:      ["client-A", "", "World"]
                      ↓  (ROUTER routes by first frame)
REQ receives:         ["World"]
```

The empty delimiter separates routing (everything before it) from
payload (everything after). With two ROUTER hops, each adds an identity
frame: `["hop2-id", "hop1-id", "", "payload"]`. Each ROUTER on the
return path peels off one identity.

### XPUB / XSUB

Like PUB/SUB but subscription events are exposed as data frames
(`\x01topic` to subscribe, `\x00topic` to unsubscribe). This lets you
build subscription-forwarding proxies — essential for multi-hop pub-sub
topologies.

```ruby
# XSUB connects to upstream publishers
xsub = Cztop::Socket::XSUB.connect('tcp://upstream:5556')

# XPUB binds for downstream subscribers
xpub = Cztop::Socket::XPUB.bind('tcp://*:5560')

# Forward subscriptions upstream, data downstream
event = xpub.receive         # => ["\x01weather"]
xsub << event.first
msg = xsub.receive
xpub << msg
```

→ see [`examples/zguide/02_pub_sub.rb`](examples/zguide/02_pub_sub.rb)

### STREAM

Raw TCP interop. Talks to non-ZMQ peers (telnet, curl, browsers).
Messages are `[identity, data]` pairs. Connect/disconnect events send
`[identity, '']`.

```ruby
stream = CZTop::Socket::STREAM.new
port = stream.bind('tcp://127.0.0.1:*')

msg = stream.receive           # connect notification
identity = msg[0]              # msg[1] == '' (new connection)

msg = stream.receive           # actual data
data = msg[1]                  # raw bytes

stream << [identity, "HTTP/1.1 200 OK\r\n\r\nHello\n"]
stream << [identity, '']      # close the connection
```

---

## Messages and framing

ZeroMQ messages are **not** byte streams. A message is one or more
*frames*, each an opaque blob of bytes with a length. Unlike TCP (where
sending "hello" then "world" might arrive as "helloworld"), ZMQ delivers
each message whole and separate.

- Messages are atomic: receive all frames or none
- Strings are length-prefixed on the wire, not null-terminated
- CZTop: `#receive` returns `Array<String>`, `#<<` accepts `String` or
  `Array<String>`

### Multipart messages

```ruby
socket << %w[routing-key header payload]
msg = socket.receive   # => ["routing-key", "header", "payload"]
```

All frames are sent and received atomically. Intermediate nodes forward
all frames without inspecting them. This is how envelopes work — address
frames at the front, payload at the back, empty delimiter between them.

### Binary data

All received data is `ASCII-8BIT` (binary). ZMQ frames are raw bytes —
no encoding is preserved. Send UTF-8, receive `ASCII-8BIT`.

```ruby
push << "\x00\x01\x02\xff".b
msg = pull.receive
msg.first.encoding    # => Encoding::ASCII_8BIT
msg.first.bytes       # => [0, 1, 2, 255]
```

---

## The envelope

REQ/REP use envelopes to track return addresses through proxy chains:

```
REQ sends:          ["Hello"]
On the wire:        ["", "Hello"]          ← REQ added empty delimiter
ROUTER receives:    ["client-id", "", "Hello"]  ← ROUTER added identity
```

Each ROUTER in the chain prepends another identity frame. REP strips
and saves the envelope, hands you the payload, then re-wraps your reply.

If you use DEALER or ROUTER directly, you manage envelopes yourself —
prepend the empty delimiter when sending through DEALER to REP, and
handle identity frames with ROUTER. Getting this wrong is the #1 source
of "my broker doesn't work" bugs.

---

## Transports

| Transport      | Syntax                  | Notes                                |
|----------------|-------------------------|--------------------------------------|
| tcp            | `tcp://host:port`       | Cross-machine. Bread and butter.     |
| ipc            | `ipc:///tmp/feed.sock`  | Unix domain socket. Fast, local.     |
| ipc (abstract) | `ipc://@name`           | Linux abstract namespace. No file.   |
| inproc         | `inproc://name`         | Inter-thread. Sub-µs. Fastest.       |
| pgm/epgm      | `pgm://iface;group:port`| IP multicast. Write-only PUB.        |

`tcp://` supports `*` for port auto-selection. `ipc://@name` uses the
Linux abstract namespace — no filesystem entry, auto-cleaned on exit.
`inproc://` requires the binding side to exist before connecting (unlike
tcp/ipc).

```ruby
# TCP with auto-selected port
server = Cztop::Socket::REP.new
port = server.bind('tcp://127.0.0.1:*')   # returns the chosen port

# IPC with abstract namespace (Linux only)
rep = Cztop::Socket::REP.bind('ipc://@myapp.rpc')
req = Cztop::Socket::REQ.connect('ipc://@myapp.rpc')

# inproc (inter-thread, same process)
Thread.new do
  pull = Cztop::Socket::PULL.bind('inproc://pipeline')
  loop { puts pull.receive.first }
end
push = Cztop::Socket::PUSH.connect('inproc://pipeline')
push << 'hello from main thread'
```

---

## Bind vs. connect

- **bind** = "I'm the stable endpoint, I'll be here a while"
- **connect** = "I'll find you at this address"

Rule of thumb: the node with a stable, well-known address binds.
Everything else connects. A socket can bind *and* connect to different
endpoints simultaneously.

CZTop types have sensible defaults (REP/ROUTER/PUB/XPUB/PULL bind;
REQ/DEALER/SUB/XSUB/PUSH/PAIR/STREAM connect), but you can override:

```ruby
# Class methods (preferred)
rep = Cztop::Socket::REP.bind('tcp://*:5555')
req = Cztop::Socket::REQ.connect('tcp://localhost:5555')

# Override with @/> prefixes
rep = Cztop::Socket::REP.new('>tcp://broker:5555')  # force connect
req = Cztop::Socket::REQ.new('@tcp://*:5555')        # force bind

# Split creation from binding (for pre-connect options)
sock = Cztop::Socket::DEALER.new
sock.identity = 'worker-1'
sock.bind('tcp://*:5555')
sock.connect('tcp://other-host:5556')
```

---

## Socket options

Options are accessed directly on the socket. Most must be set *before*
connecting (identity, HWM). Timeouts and linger can change at any time.

```ruby
sock = Cztop::Socket::REQ.new
sock.send_timeout = 1          # 1 second
sock.recv_timeout = 1          # 1 second
sock.linger = 0                # drop unsent on close
sock.identity = 'worker-1'    # ROUTER-visible identity

# nil = no timeout / wait indefinitely:
sock.send_timeout = nil
sock.linger = nil
```

Key options:

| Option             | Default | Meaning                                        |
|--------------------|---------|------------------------------------------------|
| `send_timeout`     | `nil`   | Send timeout in seconds. `nil` = block forever  |
| `recv_timeout`     | `nil`   | Receive timeout in seconds. `nil` = block forever |
| `linger`           | `0`     | Wait on close. `nil` = forever, `0` = drop      |
| `identity`         | auto    | Socket identity for ROUTER addressing            |
| `sndhwm`           | 1000    | Send high-water mark (messages)                  |
| `rcvhwm`           | 1000    | Receive high-water mark (messages)               |
| `reconnect_ivl`    | 0.1     | Reconnect interval in seconds. `nil` = disabled  |
| `reconnect_ivl_max`| 0       | Max reconnect backoff. 0 = no exponential backoff |
| `max_msg_size`     | -1      | Max inbound message size. -1 = unlimited         |
| `conflate?`        | false   | Keep only latest message (last-value semantics)  |

Timeouts raise `IO::TimeoutError` — standard Ruby IO exceptions. The
`read_timeout` / `write_timeout` aliases match Ruby's IO interface.

---

## High-water marks

Every socket has a send HWM and receive HWM (default: 1000 messages).
HWM is per-connection: a PUSH connected to 3 PULLs has 3×1000 buffer.
When full:

- **PUB, ROUTER**: drops messages (can't block — would stall all peers)
- **PUSH, REQ, DEALER**: blocks the sender (until timeout)

```ruby
sock.sndhwm = 10_000
sock.rcvhwm = 10_000
sock.set_unbounded              # HWM = 0 (unlimited)
```

---

## The context

In C, `zmq_ctx_new()` creates a context — container for all sockets.
CZTop manages this through CZMQ's global context. You never interact
with it directly. Key rules:

- Sockets are **not thread-safe** — one socket per thread
- One I/O thread handles ~1 Gbps — usually enough
- Set `linger = 0` for instant shutdown

---

## Threading and concurrency

**One socket per thread.** Violating this causes silent data corruption
or crashes. Use `inproc://` to communicate between threads — it's a
memory pipe with sub-µs latency:

```ruby
coordinator = Cztop::Socket::PAIR.new('@inproc://control')

worker = Thread.new do
  ctrl = Cztop::Socket::PAIR.new('>inproc://control')
  ctrl.recv_timeout = 1
  loop do
    cmd = ctrl.receive.first
    break if cmd == 'STOP'
    ctrl << "done:#{cmd}"
  end
end

coordinator << 'task-1'
result = coordinator.receive.first  # => "done:task-1"
coordinator << 'STOP'
worker.join
```

For multi-worker patterns, spin up one thread per worker, each with its
own socket:

```ruby
workers = 4.times.map do |id|
  Thread.new do
    rep = Cztop::Socket::REP.connect('inproc://backend')
    rep.recv_timeout = 1
    loop do
      msg = rep.receive
      rep << "worker-#{id}:#{msg.first}"
    rescue IO::TimeoutError
      break
    end
  end
end
```

CZTop's `#wait_readable`/`#wait_writable` use `IO#wait_readable`
internally, so they work with Ruby's Fiber Scheduler (e.g. Async) —
blocking calls yield the fiber. ZMQ sockets are still thread-bound, so
fibers must run on the thread that created the socket.

→ see [`examples/zguide/01_req_rep.rb`](examples/zguide/01_req_rep.rb) for a full broker example
→ see [`examples/zguide/03_pipeline.rb`](examples/zguide/03_pipeline.rb) for thread-per-worker pipeline

---

## Reliability patterns

ZeroMQ gives you no delivery guarantees out of the box. Messages can be
lost on connection drops, HWM overflow, or process crashes. The zguide
builds reliability from simple to sophisticated:

### Lazy Pirate (client-side retry)

REQ client sets a receive timeout. No reply? Close the socket, open a
new one, retry. Give up after N attempts. You must recreate the socket
because REQ's lockstep state machine is stuck after a missed recv.

```ruby
MAX_RETRIES = 3

def lazy_pirate_request(endpoint, request)
  MAX_RETRIES.times do |attempt|
    req = Cztop::Socket::REQ.connect(endpoint)
    req.recv_timeout = 2.5
    req.linger = 0

    req << request
    begin
      return req.receive.first
    rescue IO::TimeoutError, IO::EAGAINWaitReadable
      puts "attempt #{attempt + 1} timed out"
      req.close
    end
  end
  raise 'Server appears to be offline'
end
```

→ see [`examples/zguide/04_lazy_pirate.rb`](examples/zguide/04_lazy_pirate.rb)

### Simple Pirate (add a broker)

ROUTER-ROUTER queue between clients and workers. Workers send "READY"
when available, queue routes to ready workers (LRU).

### Paranoid Pirate (add heartbeating)

Workers and queue exchange periodic heartbeats. Queue evicts silent
workers. Workers reconnect if queue goes silent. Rule: heartbeat at
interval T, declare dead after T×3 silence.

### Heartbeat pattern

Simple liveness detector using PUB/SUB:

```ruby
HEARTBEAT_IVL = 1.0
DEAD_AFTER    = 3

pub = Cztop::Socket::PUB.bind('tcp://*:5555')
loop do
  pub << 'HEARTBEAT'
  sleep HEARTBEAT_IVL
end

# Subscriber side
sub = Cztop::Socket::SUB.connect('tcp://localhost:5555', prefix: 'HEARTBEAT')
sub.recv_timeout = HEARTBEAT_IVL * 1.5
misses = 0

loop do
  begin
    sub.receive
    misses = 0
  rescue IO::TimeoutError
    misses += 1
    if misses >= DEAD_AFTER
      puts 'DEAD — taking action'
      misses = 0
    end
  end
end
```

→ see [`examples/zguide/05_heartbeat.rb`](examples/zguide/05_heartbeat.rb)

### Majordomo (service-oriented broker)

Workers register by service name. Clients request by name. Broker routes
to the right worker pool. A service mesh in ~500 lines with no YAML.

### Titanic (disconnected reliability)

Broker persists requests to disk before forwarding. Store-and-forward
for when uptime matters more than latency.

### Binary Star (high availability)

Primary-backup pair with PUB/SUB heartbeats. Failover on primary death.
Fencing rule: backup only takes over if it was *also* receiving client
requests — proving the primary is truly gone, not a network partition.

### Freelance (brokerless reliability)

Client talks directly to multiple servers. Three models: sequential
failover, shotgun (blast all, take first reply), or tracked (maintain
connection state).

---

## Pub-sub reliability

PUB/SUB is fire-and-forget, but you can layer reliability on top:

### Late joiner problem

New subscribers miss earlier messages. Solutions:

- **Last Value Cache (LVC)**: proxy caches latest value per topic,
  replays to new subscribers.
- **Snapshot**: subscriber gets current state over REQ/REP, then
  switches to live PUB/SUB.

```ruby
# LVC proxy sketch
cache = {}
msg = xsub.receive.first
topic = msg.split(' ', 2).first
cache[topic] = msg
xpub << msg

# On new subscription, serve from cache
event = xpub.receive.first
if event.start_with?("\x01")
  topic = event[1..]
  xpub << cache[topic] if cache.key?(topic)
end
```

→ see [`examples/zguide/06_last_value_cache.rb`](examples/zguide/06_last_value_cache.rb)

### Slow subscriber problem

- **Suicidal Snail**: subscriber checks lag, kills itself if too far
  behind. Let supervisor restart.
- **Credit-based flow control**: subscriber sends credits (like TCP
  window), publisher only sends when credits available.

### Clone pattern

The full-stack approach: server maintains a sequenced key-value store,
publishes updates via PUB, serves snapshots via REQ/REP. Clients
subscribe first (so they don't miss updates during snapshot), then get
the snapshot, then apply buffered live updates — skipping any already
in the snapshot using the sequence number.

```ruby
# Clone client sketch
sub = Cztop::Socket::SUB.connect(pub_endpoint)
sub.recv_timeout = 1

# Subscribe first, snapshot second
req = Cztop::Socket::REQ.connect(snapshot_endpoint)
req << 'SNAPSHOT'
snapshot = req.receive.first
snapshot_seq = apply_snapshot(snapshot)

# Apply live updates, skip any with seq <= snapshot_seq
loop do
  msg = sub.receive.first
  seq, key, value = msg.split('|', 3)
  apply_update(key, value) if seq.to_i > snapshot_seq
end
```

→ see [`examples/zguide/07_clone.rb`](examples/zguide/07_clone.rb)

---

## Security: CURVE

ZeroMQ 4.0+ supports CurveZMQ — authenticated encryption built on
Curve25519 (libsodium). CZTop makes this a `curve:` kwarg on every
socket constructor.

### How it works

Each peer has a **permanent keypair** (32 bytes). On connection, they
generate **transient keypairs** for the session:

```
Client ──HELLO──▶ Server     (client's transient pubkey)
Client ◀─WELCOME─ Server     (server's transient pubkey + cookie)
Client ──INITIATE──▶ Server  (client's permanent pubkey, encrypted)
Client ◀─READY──── Server    (metadata, encrypted)
```

After this, all traffic is encrypted and authenticated. Transient keys
are discarded on close — **perfect forward secrecy**. The handshake is
DoS-resistant: HELLO > WELCOME (no amplification), minimal server state
before auth.

### CZTop CURVE API

```ruby
require 'cztop'

server_pub, server_sec = CZTop::CURVE.keypair
client_pub, client_sec = CZTop::CURVE.keypair

auth = CZTop::CURVE::Auth.new(allowed_clients: [client_pub])

rep = Cztop::Socket::REP.bind('tcp://*:5555',
  curve: { secret_key: server_sec })

req = Cztop::Socket::REQ.connect('tcp://localhost:5555',
  curve: { secret_key: client_sec, server_key: server_pub })

req << 'encrypted hello'
msg = rep.receive            # => ["encrypted hello"]

auth.stop
```

Works on any socket type. No certificates, no filesystem, no config.

### Z85 and key management

```ruby
# Z85 encoding for config files / env vars
z85 = CZTop::CURVE.z85_encode(binary_key)   # => 40-char string
key  = CZTop::CURVE.z85_decode(z85)          # => 32 bytes

# Derive public from secret
pubkey = CZTop::CURVE.public_key(secret_key)

# Dynamic key management (thread-safe)
auth = CZTop::CURVE::Auth.new(allow_any: false)
auth.allow(new_client_pubkey)
auth.deny(revoked_client_pubkey)
auth.stop
```

### ZAP — authentication

ZeroMQ sends a ZAP request over `inproc://zeromq.zap.01` with the
client's credential. Your handler replies 200 (allow) or 400 (deny).
CZTop's `CURVE::Auth` is exactly this: a background thread with a
Mutex-guarded `Set` of allowed keys.

### ZMTP: the wire protocol

ZMTP 3.x handles greeting (64-byte exchange), security handshake, and
message framing. Both peers must agree on the mechanism (NULL, PLAIN, or
CURVE). No downgrade negotiation — mismatch = connection failure. This
is a feature.

---

## CZTop API at a glance

### Socket lifecycle

```ruby
# Class methods (preferred)
pub = Cztop::Socket::PUB.bind('tcp://*:5556')
sub = Cztop::Socket::SUB.connect('tcp://localhost:5556')

# Constructor
pub = Cztop::Socket::PUB.new('tcp://*:5556')

# Split creation from binding (for pre-connect options)
pub = Cztop::Socket::PUB.new
pub.sndhwm = 50_000
pub.bind('tcp://*:5556')
pub.bind('ipc://@my-pub')       # multiple endpoints

pub.last_endpoint                # => "tcp://0.0.0.0:5556"
pub.last_tcp_port                # => 5556
pub.close                        # or let GC handle it
```

### Sending and receiving

```ruby
socket << 'hello'                         # single-frame
socket.send('hello')                      # same (shadows Object#send)
socket << ['frame1', 'frame2', 'frame3']  # multipart

msg = socket.receive   # => ["frame1", "frame2", "frame3"]
msg.first              # first frame

socket.__send__(:some_method)  # for Object#send metaprogramming
```

### FD integration

```ruby
io = socket.to_io               # IO wrapping the ZMQ FD
socket.fd                        # raw fd integer
socket.readable?                 # data is waiting?
socket.writable?                 # send won't block?
socket.wait_readable             # block until readable (or timeout)
socket.wait_writable             # block until writable (or timeout)
```

Note: the ZMQ FD is **edge-triggered**. CZTop's `FdWait` mixin handles
this internally, but raw event loop integrations need to check
`#readable?`/`#writable?` after each wakeup.

### Socket types and their mixins

| Type     | Includes          | Default action | Notes                        |
|----------|-------------------|----------------|------------------------------|
| REQ      | Readable, Writable| connect        | Strict send/recv lockstep    |
| REP      | Readable, Writable| bind           | Strict recv/send lockstep    |
| DEALER   | Readable, Writable| connect        | Async REQ, no lockstep       |
| ROUTER   | Readable, Writable| bind           | Identity-addressed routing   |
| PUB      | Writable          | bind           | Send-only                    |
| SUB      | Readable          | connect        | Receive-only, topic filtered |
| XPUB     | Readable, Writable| bind           | PUB + subscription events    |
| XSUB     | Readable, Writable| connect        | SUB + wire-protocol control  |
| PUSH     | Writable          | connect        | Send-only, round-robin       |
| PULL     | Readable          | bind           | Receive-only, fair-queued    |
| PAIR     | Readable, Writable| connect        | 1:1 bidirectional            |
| STREAM   | Readable, Writable| connect        | Raw TCP interop              |

PUB can't receive and SUB can't send — the type system prevents misuse
at the Ruby level.

---

## Common mistakes

### 1. Wrong REQ/REP ordering

REQ requires send-then-receive. Calling `#receive` on a fresh REQ hangs
forever. If the server crashes mid-request, the REQ is stuck — destroy
it and create a new one (Lazy Pirate).

### 2. Sharing sockets across threads

Not thread-safe. Silent data corruption, hangs, or segfaults. One
socket per thread. Use `inproc://` between threads.

### 3. Forgetting linger

CZTop defaults to `linger = 0`. If you changed it, `#close` blocks
until queued messages are delivered. Always `socket.linger = 0` for
sockets you want to close fast.

### 4. Not setting timeouts

`#receive` without `recv_timeout` blocks forever. Always set timeouts in
production and handle `IO::TimeoutError`.

### 5. PUB/SUB startup race

Subscription propagation takes time (µs for inproc, ms for tcp). First
messages can be lost. Synchronize with REQ/REP or add a small sleep.

### 6. Sending to an unconnected ROUTER

Messages to unknown identities vanish silently. Set
`ZMQ_ROUTER_MANDATORY` for errors instead.

### 7. Wrong envelope format

DEALER → REP requires the empty delimiter that REQ adds automatically.
Without it, REP can't parse the message.

```ruby
# WRONG
dealer << "hello"

# RIGHT
dealer << ["", "hello"]
```

---

## Design philosophy

### Unix philosophy, applied to messaging

- Small, composable pieces connected by simple protocols
- Each socket type does one thing well
- No monolithic broker — compose your own topology
- Crash and restart cleanly

### Cheap vs. Nasty

- **Cheap** (control plane): human-readable, synchronous, low-volume.
  JSON, REQ/REP. Easy to debug.
- **Nasty** (data plane): binary, async, high-volume. PUB/SUB or
  PUSH/PULL. Fast to parse.

Most code is control plane; optimize only the hot path.

---

## Topology patterns cheatsheet

```
1:1 RPC                    REQ ──▶ REP
1:N fan-out                PUB ──▶ SUB, SUB, SUB
N:1 fan-in                 PUSH, PUSH ──▶ PULL
N:M brokered               REQ ──▶ ROUTER │ broker │ DEALER ──▶ REP
N:M pub-sub proxy           PUB ──▶ XSUB │ proxy │ XPUB ──▶ SUB
Pipeline                   PUSH ──▶ PULL ──▶ PUSH ──▶ PULL
Async client-server        DEALER ──▶ ROUTER
Peer-to-peer               ROUTER ──▶ ROUTER  (hard mode)
```

---

## Practical advice from the zguide

1. **Start with the simplest pattern that works.** REQ/REP is fine
   until it isn't.
2. **Don't share sockets across threads.** One socket per thread,
   `inproc://` between them.
3. **Always set `linger`** — `sock.linger = 0` for clean shutdown.
4. **PUB/SUB filtering is prefix-based.** `""` = everything.
5. **Connect from the ephemeral side.** Stable address binds.
6. **Heartbeat everything** in production.
7. **Let ZeroMQ reconnect for you.** Close-and-reopen only for REQ
   after a timeout (Lazy Pirate).
8. **Use ROUTER for addressed routing, DEALER for async round-robin.**
9. **Multipart messages are atomic.** Use them for envelopes, not
   streaming.
10. **Set timeouts.** `recv_timeout` saves you from frozen processes.
11. **Use abstract namespace IPC on Linux** (`ipc://@name`) — no
    leftover socket files.

---

## Working examples

| File | Pattern | Key sockets |
|------|---------|-------------|
| [`01_req_rep.rb`](examples/zguide/01_req_rep.rb) | Basic echo + multi-worker broker | REQ, REP, ROUTER, DEALER |
| [`02_pub_sub.rb`](examples/zguide/02_pub_sub.rb) | Topic filter, XPUB/XSUB proxy | PUB, SUB, XPUB, XSUB |
| [`03_pipeline.rb`](examples/zguide/03_pipeline.rb) | Fan-out/fan-in ventilator | PUSH, PULL |
| [`04_lazy_pirate.rb`](examples/zguide/04_lazy_pirate.rb) | Client timeout + retry | REQ, REP |
| [`05_heartbeat.rb`](examples/zguide/05_heartbeat.rb) | Liveness detection | PUB, SUB |
| [`06_last_value_cache.rb`](examples/zguide/06_last_value_cache.rb) | Caching proxy + snapshot | PUB, SUB, REQ, REP |
| [`07_clone.rb`](examples/zguide/07_clone.rb) | Reliable state sync | PUB, SUB, REQ, REP |

Run any example: `ruby examples/zguide/03_pipeline.rb`

---

## Further reading

- [zguide](https://zguide.zeromq.org/) — the full guide, 80+ examples
  in 20+ languages
- [ZMTP 3.1 spec](https://rfc.zeromq.org/spec/23/) — wire protocol
- [CurveZMQ spec](https://rfc.zeromq.org/spec/26/) — encryption
- [ZAP spec](https://rfc.zeromq.org/spec/27/) — authentication
- [CZTop source](https://github.com/paddor/cztop) — the Ruby binding
  used in all examples above
