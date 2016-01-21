# Performance Measurement

This directory contains simple performance measurement utilities:

- `inproc_lat_pair.rb` measures the latency of the inproc transport over PAIR sockets
- `inproc_lat_reqrep.rb` measures the latency of the inproc transport over REQ/REP sockets
- `inproc_thr.rb` measures the throughput of the inproc transport
- `local_lat.rb` and `remote_lat.rb` measure the latency other transports
- `local_thr.rb` and `remote_thr.rb` measure the throughput other transports

## Example Output

On my laptop, it currently looks something like this:

inproc latency over PAIR sockets using 10k roundtrips of a repeatedly allocated
1k bytes message:
``
$ ./inproc_lat_pair.rb 1_000 10_000
message size: 1000 [B]
roundtrip count: 10000
elapsed time: 0.436 [s]
average latency: 21.801 [us]
```

inproc latency over REQ/REP sockets using 10k roundtrips of a repeatedly
allocated 1k bytes message:
```
$ ./inproc_lat_reqrep.rb 1_000 10_000
message size: 1000 [B]
roundtrip count: 10000
elapsed time: 0.469 [s]
average latency: 23.439 [us]<Paste>
```
