# Performance Measurement

This directory contains simple performance measurement utilities:

- `inproc_lat.rb` measures the latency of the inproc transport
- `inproc_thru.rb` measures the throughput of the inproc transport
- `local_lat.rb` and `remote_lat.rb` measure the latency of other transports
- `test_latency.sh` run all latency tests
- `test_throughput.sh` run all throuput tests

## Example Output

### Latency

```
$ ./test_latency.sh
ruby 3.3.0 (2023-12-25 revision 5124f9ac75) +YJIT [x86_64-linux]
#### Over inproc, using 10k roundtrips of a repeatedly allocated 1kb message:
message size: 1000 [B]
roundtrip count: 10000
elapsed time: 0.805 [s]
average latency: 40.254 [μs]

#### Over IPC, using 10k roundtrips of a repeatedly allocated 1kb message:
message size: 1000 [B]
roundtrip count: 1000
elapsed time: 0.190 [s]
average latency: 95.009 [μs]

#### Over local TCP/IP stack, using 10k roundtrips of a repeatedly allocated 1kb message:
message size: 1000 [B]
roundtrip count: 1000
elapsed time: 0.233 [s]
average latency: 116.551 [μs]
```

### Throughput

```
$ ./test_throughput.sh
ruby 3.3.0 (2023-12-25 revision 5124f9ac75) +YJIT [x86_64-linux]
#### Over inproc, with 10,000 messages of 100 bytes:
message size: 100 [B]
message count: 10000
elapsed time: 0.446 [s]
mean throughput: 22438 [msg/s]
mean throughput: 17.951 [Mb/s]

#### Over inproc, with 10,000 messages of 1,000 bytes:
message size: 1000 [B]
message count: 10000
elapsed time: 0.438 [s]
mean throughput: 22808 [msg/s]
mean throughput: 182.465 [Mb/s]

#### Over inproc, with 10,000 messages of 10,000 bytes:
message size: 10000 [B]
message count: 10000
elapsed time: 0.513 [s]
mean throughput: 19478 [msg/s]
mean throughput: 1558.270 [Mb/s]

#### Over inproc, with 10,000 messages of 100,000 bytes:
message size: 100000 [B]
message count: 10000
elapsed time: 0.705 [s]
mean throughput: 14193 [msg/s]
mean throughput: 11354.498 [Mb/s]
```
