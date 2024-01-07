# Performance Measurement

This directory contains simple performance measurement utilities:

- `inproc_lat.rb` measures the latency of the inproc transport
- `inproc_thru.rb` measures the throughput of the inproc transport
- `local_lat.rb` and `remote_lat.rb` measure the latency of other transports
- `local_thru.rb` and `remote_thru.rb` measure the throughput of other transports (TODO)

## Example Output

On my laptop, it currently looks something like this:

### Latency

over inproc, using 10k roundtrips of a repeatedly allocated 1kb message:
```
$ bundle exec ./inproc_lat_reqrep.rb 1_000 10_000
message size: 1000 [B]
roundtrip count: 10000
elapsed time: 0.469 [s]
average latency: 23.439 [us]
```

over IPC, using 10k roundtrips of a repeatedly allocated 1kb message:
```
$ bundle exec ./local_lat.rb ipc:///tmp/cztop-perf 1000 1000 & ./remote_lat.rb ipc:///tmp/cztop-perf 1000 1000
[3] 58043
message size: 1000 [B]
roundtrip count: 1000
elapsed time: 0.091 [s]
average latency: 45.482 [us]
[3]    58043 done       ./local_lat.rb ipc:///tmp/cztop-perf 1000 1000
```

over local TCP/IP stack, using 10k roundtrips of a repeatedly allocated
1kb message:
```
$ bundle exec ./local_lat.rb tcp://127.0.0.1:55667 1000 1000 & ./remote_lat.rb tcp://127.0.0.1:55667 1000 1000
[3] 58064
message size: 1000 [B]
roundtrip count: 1000
elapsed time: 0.123 [s]
average latency: 61.434 [us]
[3]    58064 done       ./local_lat.rb tcp://127.0.0.1:55667 1000 1000
```

### Throughput

over inproc, with message sizes from 100 bytes to 100kb, 10,000 each:

```
$ bundle exec ./inproc_thru.rb 100 10_000
message size: 100 [B]
message count: 10000
elapsed time: 0.270 [s]
mean throughput: 37093 [msg/s]
mean throughput: 29.674 [Mb/s]

$ bundle exec ./inproc_thru.rb 1_000 10_000
message size: 1000 [B]
message count: 10000
elapsed time: 0.260 [s]
mean throughput: 38498 [msg/s]
mean throughput: 307.987 [Mb/s]

$ bundle exec ./inproc_thru.rb 10_000 10_000
message size: 10000 [B]
message count: 10000
elapsed time: 0.317 [s]
mean throughput: 31501 [msg/s]
mean throughput: 2520.102 [Mb/s]

$ bundle exec ./inproc_thru.rb 100_000 10_000
message size: 100000 [B]
message count: 10000
elapsed time: 0.906 [s]
mean throughput: 11034 [msg/s]
mean throughput: 8827.440 [Mb/s]
```
