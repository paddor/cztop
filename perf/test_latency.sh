#! /bin/sh
export RUBYOPT='--jit'

ruby -v

echo "#### Over inproc, using 10k roundtrips of a repeatedly allocated 1kb message:"
./inproc_lat.rb 1_000 10_000
echo

echo "#### Over IPC, using 10k roundtrips of a repeatedly allocated 1kb message:"
./local_lat.rb ipc:///tmp/cztop-perf 1000 1000 & ./remote_lat.rb ipc:///tmp/cztop-perf 1000 1000
echo

echo "#### Over local TCP/IP stack, using 10k roundtrips of a repeatedly allocated 1kb message:"
./local_lat.rb tcp://127.0.0.1:55667 1000 1000 & ./remote_lat.rb tcp://127.0.0.1:55667 1000 1000
