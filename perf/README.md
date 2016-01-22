# Performance Measurement

This directory contains simple performance measurement utilities:

- `inproc_lat.rb` measures the latency of the inproc transport
- `inproc_thr.rb` measures the throughput of the inproc transport
- `local_lat.rb` and `remote_lat.rb` measure the latency other transports
- `local_thr.rb` and `remote_thr.rb` measure the throughput other transports

## Example Output

On my laptop, it currently looks something like this:

inproc latency over PAIR sockets using 10k roundtrips of a repeatedly allocated
1kb message:
``
$ ./inproc_lat_pair.rb 1_000 10_000
message size: 1000 [B]
roundtrip count: 10000
elapsed time: 0.436 [s]
average latency: 21.801 [us]
```

inproc latency over REQ/REP sockets using 10k roundtrips of a repeatedly
allocated 1kb message:
```
$ ./inproc_lat_reqrep.rb 1_000 10_000
message size: 1000 [B]
roundtrip count: 10000
elapsed time: 0.469 [s]
average latency: 23.439 [us]<Paste>
```

latency over REQ/REP sockets over IPC using 10k roundtrips of a repeatedly
allocated 1kb message:
```
$ ./local_lat.rb ipc:///tmp/cztop-perf 1000 1000 & ./remote_lat.rb ipc:///tmp/cztop-perf 1000 1000
[3] 58043
message size: 1000 [B]
roundtrip count: 1000
elapsed time: 0.091 [s]
average latency: 45.482 [us]
[3]    58043 done       ./local_lat.rb ipc:///tmp/cztop-perf 1000 1000
```

latency over REQ/REP sockets over local TCP/IP stack using 10k roundtrips of a repeatedly
allocated 1kb message:
```
[3] 58064
message size: 1000 [B]
roundtrip count: 1000
elapsed time: 0.123 [s]
average latency: 61.434 [us]
[3]    58064 done       ./local_lat.rb tcp://127.0.0.1:55667 1000 1000
```
