0.6.1 (20/09/2016)
-----
* no changes, but this release includes up-to-date version of this file

0.6.0 (20/09/2016)
-----
* upgrade to czmq-ffi-gen's 0.9.x line (which supports fat gems for Windows)

0.5.0 (28/06/2016)
-----
* new example (weather PUB/SUB)
* add option to enable IPv6 on sockets
* avoid $DEBUG warnings
* fix specs on Rubinius
* better documentation
* minor CI improvements

0.4.0 (13/04/2016)
-----
* CZTop::Poller learns the following methods for convenience and compatibility:
  * #add_reader
  * #add_writer
  * #remove_reader
  * #remove_writer
* CZTop::Poller::Aggregated gets method delegators for the following 8 methods
  for compatibility:
  * CZTop::Poller#add
  * CZTop::Poller#add_reader
  * CZTop::Poller#add_writer
  * CZTop::Poller#modify
  * CZTop::Poller#remove
  * CZTop::Poller#remove_reader
  * CZTop::Poller#remove_writer
  * CZTop::Poller#sockets

0.3.0 (13/04/2016)
-----
* port CZTop::Poller to zmq_poller_*() functions so it supports thread-safe
  sockets as well
* extract niche features to CZTop::Poller::Aggregated
* fix taxi system example
* drop support for CZMQ 3.0.2, ZMQ 4.0 and ZMQ 4.1

0.2.1 (31/01/2016)
-----
* improve documentation
* improve test suite

0.2.0 (27/01/2016)
-----
* simplify CZTop::Z85::Padded
  * no length encoding
  * padding similar to PKCS#7
* add utilities `z85encode` and `z85decode`
* add CZTop::Z85::Pipe
* CZTop::SUB#subscribe: subscribe to everything if no parameter given

0.1.1 (23/01/2016)
-----
* add support for Ruby 2.0
* improve documentation
* fix require()s in examples

0.1.0 (23/01/2016)
-----
* first release
