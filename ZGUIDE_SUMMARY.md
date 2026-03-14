# The ZeroMQ Guide — Condensed

A distillation of [the zguide](https://zguide.zeromq.org/) for
Unix-philosophy people who'd rather `pipe(2)` things together than deploy
a message broker. Examples use [CZTop](https://github.com/paddor/cztop)
(Ruby FFI binding for CZMQ/ZMQ).

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

Good for: RPC, command-response, simple services.

```ruby
require 'cztop'

# --- server.rb ---
rep = CZTop::Socket::REP.new('tcp://*:5555')
loop do
  msg = rep.receive            # => ["Hello"]
  rep << "World"
end

# --- client.rb ---
req = CZTop::Socket::REQ.new('tcp://localhost:5555')
req << "Hello"
reply = req.receive            # => ["World"]
```

Scaling it up: stick a ROUTER/DEALER proxy in the middle and fan out to
N workers without changing client code.

### 2. PUB/SUB — Publish-Subscribe

```
  publisher (PUB)  ──msg──▶  subscriber 1 (SUB)
                   ──msg──▶  subscriber 2 (SUB)
                   ──msg──▶  subscriber N (SUB)
```

PUB sends to all connected SUBs. SUB filters by topic prefix. In CZTop,
`SUB.new` subscribes to everything by default; pass `prefix:` to filter
or `prefix: nil` to defer.

Late-joining subscribers miss earlier messages — this is by design,
like tuning into a radio station. If you need catch-up, layer a
snapshot mechanism on top (see Clone pattern below).

PUB never blocks; if a subscriber is slow, messages are dropped once the
high-water mark is hit.

```ruby
# --- publisher.rb ---
pub = CZTop::Socket::PUB.new('tcp://*:5556')
loop do
  pub << "weather.nyc #{rand(60..100)}F"
  pub << "weather.sfo #{rand(50..80)}F"
  sleep 1
end

# --- subscriber.rb ---
sub = CZTop::Socket::SUB.new('tcp://localhost:5556', prefix: 'weather.nyc')
loop do
  msg = sub.receive             # => ["weather.nyc 74F"]
  puts msg.first
end

# --- subscribe to everything (the default) ---
sub = CZTop::Socket::SUB.new('tcp://localhost:5556')

# --- defer subscription, add later ---
sub = CZTop::Socket::SUB.new('tcp://localhost:5556', prefix: nil)
sub.subscribe('weather.sfo')
```

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

Good for: parallel task distribution, map-reduce, log aggregation.

```ruby
# --- ventilator.rb ---
push = CZTop::Socket::PUSH.new('tcp://*:5557')
100.times { |i| push << "task #{i}" }

# --- worker.rb (run N of these) ---
pull = CZTop::Socket::PULL.new('tcp://localhost:5557')
sink = CZTop::Socket::PUSH.new('tcp://localhost:5558')
loop do
  task = pull.receive.first
  result = process(task)
  sink << result
end

# --- sink.rb ---
pull = CZTop::Socket::PULL.new('tcp://*:5558')
loop { puts pull.receive.first }
```

### 4. PAIR — Exclusive Pair

One-to-one, bidirectional, no routing. Designed for coordinating two
threads within a process via inproc. Not meant for network use.

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

Beyond the four basic patterns, ZeroMQ provides "raw" socket types that
give you manual control over routing:

### ROUTER

A ROUTER socket tracks every connection with an *identity* (either
auto-generated or set explicitly via `socket.identity=`). When
it receives a message, it prepends the sender's identity frame. When you
send, you provide the target identity as the first frame — the ROUTER
looks up the connection and delivers. Messages to unknown identities are
silently dropped (unless `ZMQ_ROUTER_MANDATORY` is set).

ROUTER is the workhorse of every broker and proxy pattern in the zguide.

```ruby
router = CZTop::Socket::ROUTER.new('tcp://*:5559')

# Receive: [client_identity, "", "Hello"]
msg = router.receive
identity = msg[0]

# Reply to that specific client
router << [identity, "", "World"]
```

### DEALER

An async REQ. It round-robins outgoing messages across connections and
fair-queues incoming messages, but without the send/recv lockstep. You
manage envelopes yourself.

```ruby
dealer = CZTop::Socket::DEALER.new('tcp://localhost:5559')
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

In C, `zmq_proxy(frontend, backend, capture)` — one function call, runs
forever, handles load balancing. In Ruby, you'd loop on both sockets
(or use poll/threads). Add workers by just connecting more processes.
Remove them by killing the process; ZeroMQ handles the cleanup.

### XPUB / XSUB

Like PUB/SUB but subscription messages are exposed as data frames
(`\x01topic` to subscribe, `\x00topic` to unsubscribe). This lets you
build subscription-forwarding proxies — essential for multi-hop pub-sub
topologies.

```ruby
# XSUB connects to upstream publishers
xsub = CZTop::Socket::XSUB.new('tcp://upstream:5556')

# XPUB binds for downstream subscribers
xpub = CZTop::Socket::XPUB.new('tcp://*:5560')

# When a SUB connects and subscribes, XPUB receives it:
event = xpub.receive         # => ["\x01weather"]
# Forward subscription upstream so the publisher knows:
xsub << event.first

# Forward data from publisher to subscribers:
msg = xsub.receive
xpub << msg
```

### STREAM

Raw TCP interop. A STREAM socket talks to non-ZMQ TCP peers (telnet,
curl, browsers, legacy services). Messages are framed as
`[identity, data]` pairs. Connect notification: `[identity, '']`.
Disconnect: same.

```ruby
stream = CZTop::Socket::STREAM.new
port = stream.bind('tcp://127.0.0.1:*')

# Accept a raw TCP client (e.g. from netcat, curl, TCPSocket)
msg = stream.receive           # connect notification
identity = msg[0]              # opaque routing identity
                               # msg[1] == '' (empty = new connection)

msg = stream.receive           # actual data from the TCP client
data = msg[1]                  # raw bytes

# Reply to the TCP client
stream << [identity, "HTTP/1.1 200 OK\r\n\r\nHello\n"]

# Close the connection: send [identity, '']
stream << [identity, '']
```

---

## Messages and framing

ZeroMQ messages are **not** byte streams. A message is one or more
*frames*, each an opaque blob of bytes with a length.

```
frame = flags(1 byte) + size(1 or 8 bytes) + body
```

- `MORE` flag: more frames follow in this message
- `COMMAND` flag: this is a protocol command, not application data
- Messages are atomic: you receive all frames or none

Strings are **not null-terminated** on the wire. They're length-prefixed.
If you're in C, you need to null-terminate after receiving. In Ruby —
CZTop handles this. `#receive` returns `Array<String>`, `#send` (or
`#<<`) accepts `String` or `Array<String>`.

### Multipart messages

```ruby
socket << %w[routing-key header payload]
msg = socket.receive   # => ["routing-key", "header", "payload"]
```

All frames in a multipart message are sent and received atomically.
Intermediate nodes (proxies, brokers) forward all frames without
inspecting them. This is how envelopes work — address frames live at the
front, payload at the back, with an empty delimiter frame between them.

### Binary data

ZMQ frames are binary-safe. CZTop preserves encoding:

```ruby
push << "\x00\x01\x02\xff".b
msg = pull.receive
msg.first.encoding    # => Encoding::ASCII_8BIT
msg.first.bytes       # => [0, 1, 2, 255]
```

---

## The envelope

REQ/REP use envelopes to track return addresses through chains of
proxies:

```
REQ sends:          ["Hello"]
On the wire:        ["", "Hello"]          ← REQ added empty delimiter
ROUTER receives:    ["client-id", "", "Hello"]  ← ROUTER added identity
```

Each ROUTER in the chain prepends another identity frame. REP strips and
saves the envelope, hands you the payload, then re-wraps your reply so
it gets routed back.

If you use DEALER or ROUTER directly, you manage envelopes yourself.
This means manually prepending the empty delimiter frame when sending
through a DEALER, and stripping/restoring identity frames when working
with ROUTER.

---

## Transports

| Transport      | Syntax                  | Notes                                |
|----------------|-------------------------|--------------------------------------|
| tcp            | `tcp://host:port`       | Cross-machine. Bread and butter.     |
| ipc            | `ipc:///tmp/feed.sock`  | Unix domain socket. Fast, local.     |
| ipc (abstract) | `ipc://@name`           | Linux abstract namespace. No file.   |
| inproc         | `inproc://name`         | Inter-thread via shared context. Fastest. |
| pgm/epgm      | `pgm://iface;group:port`| IP multicast. Write-only PUB.        |

`tcp://` supports `*` for binding to all interfaces and `*` for port
(auto-select). `ipc://` is just a path. `ipc://@name` uses the Linux
abstract socket namespace — no filesystem entry, auto-cleaned on process
exit. `inproc://` is a named memory pipe — no kernel involvement,
sub-microsecond latency.

```ruby
# TCP with auto-selected port
server = CZTop::Socket::REP.new
port = server.bind('tcp://127.0.0.1:*')   # returns the chosen port
# port is also in server.last_tcp_port

# IPC with abstract namespace (Linux only)
rep = CZTop::Socket::REP.new('ipc://@myapp.rpc')
req = CZTop::Socket::REQ.new('ipc://@myapp.rpc')

# inproc (inter-thread, same process)
Thread.new do
  pull = CZTop::Socket::PULL.new('inproc://pipeline')
  loop { puts pull.receive.first }
end
push = CZTop::Socket::PUSH.new('>inproc://pipeline')
push << 'hello from main thread'
```

---

## Bind vs. connect

Unlike traditional sockets, ZeroMQ decouples bind/connect from
server/client roles:

- **bind** = "I'm the stable endpoint, I'll be here a while"
- **connect** = "I'll find you at this address"

You can connect before the bind exists. ZeroMQ queues messages and
reconnects automatically. You can bind one socket to multiple endpoints,
or connect one socket to multiple endpoints.

Rule of thumb: the node with a stable, well-known address binds.
Everything else connects.

CZTop socket types have sensible defaults (REP/ROUTER/PUB/XPUB/PULL
bind; REQ/DEALER/SUB/XSUB/PUSH/PAIR/STREAM connect), but you can
override with `@`/`>` prefixes:

```ruby
# Default: REP binds
rep = CZTop::Socket::REP.new('tcp://*:5555')

# Override: force REP to connect (unusual but legal)
rep = CZTop::Socket::REP.new('>tcp://broker:5555')

# Override: force REQ to bind
req = CZTop::Socket::REQ.new('@tcp://*:5555')

# Or use explicit methods
sock = CZTop::Socket::DEALER.new
sock.bind('tcp://*:5555')
sock.connect('tcp://other-host:5556')
# Yes — the same socket can bind AND connect to different endpoints
```

---

## Socket options

Options are accessed directly on the socket:

```ruby
sock = CZTop::Socket::REQ.new
sock.send_timeout = 1          # send timeout: 1 second
sock.recv_timeout = 1          # receive timeout: 1 second
sock.linger = 0            # don't wait on close
sock.identity = 'worker-1' # ROUTER-visible identity

# nil means "no timeout" / "wait indefinitely":
sock.send_timeout = nil
sock.linger = nil
```

Key options:

| Option         | Default | Meaning                                        |
|----------------|---------|------------------------------------------------|
| `send_timeout`     | `nil`   | Send timeout in seconds. `nil` = block forever  |
| `recv_timeout`     | `nil`   | Receive timeout in seconds. `nil` = block forever |
| `linger`       | `0`     | Seconds to wait for delivery on close. `nil` = forever, `0` = drop |
| `identity`     | auto    | Socket identity for ROUTER addressing            |
| `sndhwm`       | 1000    | Send high-water mark (messages)                  |
| `rcvhwm`       | 1000    | Receive high-water mark (messages)               |
| `reconnect_ivl`| 0.1     | Reconnect interval in seconds. `nil` = disabled  |

Timeouts raise `IO::TimeoutError` or `IO::EAGAINWaitReadable` /
`IO::EAGAINWaitWritable` — standard Ruby IO exceptions.

---

## High-water marks

Every socket has a send HWM and receive HWM (default: 1000 messages).
When the queue is full:

- **PUB**: drops messages (publisher never blocks)
- **PUSH, DEALER**: blocks the sender (until timeout)
- **ROUTER**: drops (you can't block a router)

```ruby
sock.sndhwm = 10_000    # allow more buffering
sock.rcvhwm = 10_000
sock.set_unbounded              # HWM = 0 (unlimited; hope you have RAM)
```

---

## The context

In C, `zmq_ctx_new()` creates a context — the container for all sockets
and I/O threads. CZTop manages this for you through CZMQ's global
context. You almost never interact with it directly.

Key rules still apply:

- Sockets are **not thread-safe**. Don't share them across threads. Use
  inproc to communicate between threads.
- One I/O thread handles ~1 Gbps of throughput. Usually enough.
- Set `linger = 0` on sockets if you want instant shutdown without
  blocking.

---

## Reliability patterns

ZeroMQ gives you no delivery guarantees out of the box. It's a
*transport*, not a *transaction manager*. The zguide builds reliability
from simple to sophisticated:

### Lazy Pirate (client-side retry)

REQ client polls with a timeout. No reply? Close the socket, open a new
one, retry. Give up after N attempts. Simple, works for single-server
setups.

```ruby
MAX_RETRIES = 3

def lazy_pirate_request(endpoint, request)
  MAX_RETRIES.times do
    req = CZTop::Socket::REQ.new(endpoint)
    req.recv_timeout = 2.5     # 2.5 second timeout
    req.linger = 0

    req << request
    begin
      return req.receive.first     # success
    rescue IO::TimeoutError, IO::EAGAINWaitReadable
      req.close                    # timed out, reconnect
    end
  end
  raise 'Server appears to be offline'
end
```

### Simple Pirate (add a broker)

Put a ROUTER-ROUTER queue between clients and workers. Workers send
"READY" when available. Queue routes work to ready workers (LRU). If a
worker dies, the queue just stops sending it work.

### Paranoid Pirate (add heartbeating)

Workers and queue exchange heartbeats. Queue evicts silent workers.
Workers reconnect if the queue goes silent. Clients still do Lazy
Pirate retries.

Heartbeat strategies:
- **One-way**: server pings, client watches
- **Ping-pong**: bidirectional, detects both sides
- **At-interval**: periodic, not request-triggered (avoids false timeouts
  under load)

Rule: heartbeat at interval T, declare dead after T×3 silence.

### Majordomo (service-oriented broker)

Workers register by service name. Clients request services by name.
Broker routes to the right worker pool. Essentially a service mesh in
~500 lines with no YAML.

### Titanic (disconnected reliability)

Broker persists requests to disk before forwarding. Clients can
disconnect; their requests survive broker restarts. Store-and-forward
for when uptime matters more than latency.

### Binary Star (high availability)

Primary-backup pair. Primary handles traffic, backup monitors
heartbeat. Failover on primary death. Fencing protocol prevents
split-brain.

### Freelance (brokerless reliability)

Client talks directly to multiple servers. Three models:
1. Try servers sequentially, failover on timeout
2. Shotgun: blast to all servers, take first reply
3. Tracked: maintain connection state, route intelligently

---

## Pub-sub reliability

PUB/SUB is inherently unreliable (fire-and-forget), but the zguide
shows how to layer reliability on top:

### Late joiner problem

New subscribers miss messages sent before they connected. Solutions:

- **Last Value Cache (LVC)**: XSUB/XPUB proxy keeps latest value per
  topic. On new subscription, replays cached value immediately.
- **Snapshot**: subscriber asks the publisher for current state over a
  separate REQ/REP channel, then switches to live PUB/SUB feed.

### Slow subscriber problem

Subscribers that can't keep up cause PUB-side queue buildup until HWM,
then message loss.

- **Suicidal Snail**: subscriber timestamps received messages. If lag
  exceeds threshold (e.g. 1 second), it kills itself rather than
  process stale data. Let your supervisor restart it.
- **Credit-based flow control**: subscriber sends credits (like TCP
  window). Publisher only sends when credits are available.

### Clone pattern

The full-stack approach to reliable pub-sub with state:

1. Server maintains key-value store
2. Client connects, requests snapshot (REQ/REP)
3. Client subscribes to updates (SUB)
4. Client applies snapshot, then live updates (ordered by sequence number)
5. Clients can publish updates back (PUSH to server)
6. Server sequences, stores, and redistributes

Supports subtree subscriptions, ephemeral values (TTL-based expiry), and
Binary Star failover. This is the zguide's answer to "I want Redis-like
pub-sub but distributed."

---

## Security: CURVE

ZeroMQ 4.0+ supports CurveZMQ — authenticated encryption built on
Daniel Bernstein's NaCl (libsodium). CZTop makes this a `curve:` kwarg
on every socket constructor.

### How it works

Each peer has a **permanent keypair** (Curve25519, 32 bytes). On
connection, they generate **transient keypairs** for the session. The
handshake:

```
Client ──HELLO──▶ Server     (client's transient pubkey)
Client ◀─WELCOME─ Server     (server's transient pubkey + cookie)
Client ──INITIATE──▶ Server  (client's permanent pubkey, encrypted)
Client ◀─READY──── Server    (metadata, encrypted)
```

After this, all traffic is encrypted and authenticated. Transient keys
are discarded when the connection closes — **perfect forward secrecy**.
Recording ciphertext today doesn't help you if long-term keys leak
tomorrow.

### CZTop CURVE API

```ruby
require 'cztop'

# Generate keypairs (32-byte binary strings)
server_pub, server_sec = CZTop::CURVE.keypair
client_pub, client_sec = CZTop::CURVE.keypair

# Start an auth handler — decides who can connect
auth = CZTop::CURVE::Auth.new(allowed_clients: [client_pub])
# Or: auth = CZTop::CURVE::Auth.new(allow_any: true)

# Server: just pass its secret key
rep = CZTop::Socket::REP.new('tcp://*:5555',
  curve: { secret_key: server_sec })

# Client: pass its secret key + the server's public key
req = CZTop::Socket::REQ.new('tcp://localhost:5555',
  curve: { secret_key: client_sec, server_key: server_pub })

req << 'encrypted hello'
msg = rep.receive            # => ["encrypted hello"]
rep << 'encrypted world'

auth.stop
```

That's it. No certificates, no filesystem, no config. Works on any
socket type — REQ/REP, PUB/SUB, PUSH/PULL, ROUTER/DEALER, all of them.

### Dynamic key management

```ruby
auth = CZTop::CURVE::Auth.new(allow_any: false)

# Add and remove client keys at runtime (thread-safe)
auth.allow(new_client_pubkey)
auth.deny(revoked_client_pubkey)

auth.stop
```

### Z85 encoding

CURVE keys are 32 bytes of binary. For config files, environment
variables, or command-line arguments, use Z85 encoding (ZMQ's base-85):

```ruby
z85 = CZTop::CURVE.z85_encode(binary_key)   # => 40-char printable string
key  = CZTop::CURVE.z85_decode(z85)          # => 32 bytes binary

# Derive public key from secret key
pubkey = CZTop::CURVE.public_key(secret_key)
```

### What it protects against

Eavesdropping, tampering, replay attacks (nonces), man-in-the-middle
(permanent keys pinned ahead of time), client identification (permanent
key sent encrypted), amplification attacks (HELLO is larger than
WELCOME), and denial-of-service (minimal server state before
authentication).

### ZAP — authentication

The ZeroMQ Authentication Protocol lets you plug in your own auth logic.
ZeroMQ sends a ZAP request (over `inproc://zeromq.zap.01`) containing
the client's credential (public key for CURVE), and your handler replies
200 (allow) or 400 (deny). No filesystem, no external service required —
just a REP socket answering yes/no.

CZTop's `CURVE::Auth` is exactly this: a background thread running a REP
socket on the ZAP endpoint, with a Mutex-guarded `Set` of allowed keys.

### ZMTP: the wire protocol

ZeroMQ Message Transport Protocol (ZMTP 3.x) handles greeting, version
negotiation, security handshake, and message framing. The greeting is a
fixed 64-byte exchange: signature, version, mechanism name (NULL, PLAIN,
or CURVE), and role flag. After greeting, the selected security
mechanism completes its handshake, then message frames flow.

Both peers must agree on the security mechanism. No downgrade
negotiation — if one side says CURVE and the other says NULL, the
connection fails. This is a feature.

---

## CZTop API at a glance

### Socket lifecycle

```ruby
# Create + bind/connect in one call (most common)
pub = CZTop::Socket::PUB.new('tcp://*:5556')

# Or split creation from binding (for pre-connect options)
pub = CZTop::Socket::PUB.new
pub.sndhwm = 50_000
pub.bind('tcp://*:5556')
pub.bind('ipc://@my-pub')       # bind to multiple endpoints

# Inspection
pub.last_endpoint                # => "tcp://0.0.0.0:5556"
pub.last_tcp_port                # => 5556

# Cleanup
pub.close                        # explicit close (or let GC handle it)
```

### Sending and receiving

```ruby
# Send a single-frame message
socket << 'hello'
socket.send('hello')             # same thing (shadows Object#send)

# Send a multipart message
socket << ['frame1', 'frame2', 'frame3']

# Receive — always returns Array<String>
msg = socket.receive             # => ["frame1", "frame2", "frame3"]
msg.first                        # first frame

# If you need Object#send for metaprogramming:
socket.__send__(:some_method)
```

### FD integration

Every ZMQ socket has a selectable file descriptor for integration with
event loops (`IO.select`, `nio4r`, Async, etc.):

```ruby
io = socket.to_io               # => IO object wrapping the ZMQ FD
socket.fd                        # => raw fd integer
socket.readable?                 # => true if data is waiting
socket.writable?                 # => true if send won't block
socket.wait_readable             # blocks until readable (or timeout)
socket.wait_writable             # blocks until writable (or timeout)
```

Note: the ZMQ FD is **edge-triggered**, not level-triggered. CZTop's
`FdWait` mixin handles the edge-trigger dance internally, but if you're
integrating with a raw event loop, be aware that the FD signals
"something changed" — you must check `#readable?`/`#writable?` after
each wakeup.

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

Note how PUB can't receive and SUB can't send. The type system prevents
misuse at the Ruby level — no method, no mistake.

---

## Design philosophy

The zguide is opinionated. Its recurring themes:

### Unix philosophy, applied to messaging

- Small, composable pieces connected by simple protocols
- Each socket type does one thing well
- No monolithic broker — compose your own topology
- Processes talk over sockets, not shared memory
- Crash and restart cleanly (let the supervisor handle it)

### Cheap vs. Nasty

Separate your control plane from your data plane:

- **Cheap** (control): human-readable, synchronous, low-volume. JSON,
  HTTP, REQ/REP. Easy to debug with `tcpdump`.
- **Nasty** (data): binary, async, high-volume. Hand-optimized framing,
  PUB/SUB or PUSH/PULL. Fast to parse.

Don't use the same serialization for both. Most code is control plane;
optimize only the hot path.

### Protocols, not APIs

Design your distributed system as a protocol first, then implement it.
Protocols survive language rewrites, API changes, and team turnover.
Write a short spec (RFC-style), give it a name, version it. The zguide
calls these "unprotocols" — lightweight, practical, no committee.

### No road maps

The zguide argues against feature road maps. Instead: identify problems,
write minimal patches, merge fast, let the market (users) decide what
survives. This is the C4 (Collective Code Construction Contract) that
governs ZeroMQ's own development.

---

## Topology patterns cheatsheet

```
1:1 RPC
  REQ ──▶ REP

1:N fan-out
  PUB ──▶ SUB, SUB, SUB

N:1 fan-in
  PUSH, PUSH ──▶ PULL

N:M brokered
  REQ ──▶ ROUTER │ broker │ DEALER ──▶ REP

N:M pub-sub proxy
  PUB ──▶ XSUB │ proxy │ XPUB ──▶ SUB

Pipeline
  PUSH ──▶ PULL ──▶ PUSH ──▶ PULL

Async client-server
  DEALER ──▶ ROUTER

Peer-to-peer
  ROUTER ──▶ ROUTER  (hard mode)
```

---

## Practical advice from the zguide

1. **Start with the simplest pattern that works.** REQ/REP is fine
   until it isn't.

2. **Don't share sockets across threads.** Use inproc to communicate
   between threads, one socket per thread.

3. **Always set `linger`** if you want clean shutdown. Otherwise
   `#close` will block waiting to deliver queued messages.

   ```ruby
   sock.linger = 0    # drop unsent messages immediately
   ```

4. **PUB/SUB filtering is prefix-based.** Subscribe to `"weather.nyc"`
   and you'll get `"weather.nyc.temp"` and `"weather.nyc.wind"`. Subscribe
   to `""` (empty string, CZTop's default) to get everything.

5. **Connect, don't bind, from the ephemeral side.** Workers connect to
   brokers. Subscribers connect to publishers. The stable address binds.

6. **Heartbeat everything** in production. Networks lie. Processes hang.
   VMs get migrated.

7. **Let ZeroMQ reconnect for you.** Don't write reconnection logic.
   Close-and-reopen only for REQ sockets after a timeout (Lazy Pirate).

8. **Use ROUTER when you need to address specific peers.** Use DEALER
   when you just need async round-robin.

9. **Multipart messages are atomic.** Use them for envelopes. Don't use
   them to stream large data — send chunks as separate messages with
   sequence numbers.

10. **Profile before optimizing.** ZeroMQ's overhead is usually not your
    bottleneck. Your serialization, your database, your business logic —
    those are.

11. **Set timeouts.** A socket without `recv_timeout` will block forever on
    `#receive`. In production, always set timeouts and handle the
    exceptions.

    ```ruby
    sock.recv_timeout = 5       # 5 seconds
    begin
      msg = sock.receive
    rescue IO::TimeoutError
      # handle it
    end
    ```

12. **Use abstract namespace IPC on Linux** (`ipc://@name`) to avoid
    leftover socket files. No cleanup needed, no permission issues with
    `/tmp`.

---

## Further reading

- [zguide](https://zguide.zeromq.org/) — the full guide, with 80+
  working examples in 20+ languages
- [ZMTP 3.1 spec](https://rfc.zeromq.org/spec/23/) — wire protocol
- [CurveZMQ spec](https://rfc.zeromq.org/spec/26/) — encryption
- [ZAP spec](https://rfc.zeromq.org/spec/27/) — authentication
- [C4 spec](https://rfc.zeromq.org/spec/42/) — how ZeroMQ is developed
- [CZTop source](https://github.com/paddor/cztop) — the Ruby binding
  used in all examples above
