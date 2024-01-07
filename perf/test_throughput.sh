#! /bin/sh
export RUBYOPT='--jit'

ruby -v

echo "#### Over inproc, with 10,000 messages of 100 bytes:"
./inproc_thru.rb 100 10_000
echo

echo "#### Over inproc, with 10,000 messages of 1,000 bytes:"
./inproc_thru.rb 1_000 10_000
echo

echo "#### Over inproc, with 10,000 messages of 10,000 bytes:"
./inproc_thru.rb 10_000 10_000
echo

echo "#### Over inproc, with 10,000 messages of 100,000 bytes:"
./inproc_thru.rb 100_000 10_000
