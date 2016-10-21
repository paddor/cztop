0.9.3 (10/22/2016)
-----
* no changes, but this release includes an up-to-date version of this file

0.9.2 (10/21/2016)
-----
* fix Beacon#configure (thanks to Chris Olstrom)

0.9.1 (10/21/2016)
-----
* Certificate.new_from: allow constructing a certificate with only a public key

0.9.0 (10/20/2016)
-----
* add CertStore interface to zcertstore
* add ability to pass an existing CertStore to Authenticator
* add ZAP Request/Response classes (useful for testing)

0.8.0 (09/25/2016)
-----
* update dependency of czmq-ffi-gen to "~> 0.10.0"

0.7.0 (09/22/2016)
-----
* CZTop::ZsockOptions::OptionsAccessor learns #fd and #events
* fix date format in this file

0.6.1 (09/20/2016)
-----
* no changes, but this release includes an up-to-date version of this file

0.6.0 (09/20/2016)
-----
* upgrade to czmq-ffi-gen's 0.9.x line (which supports fat gems for Windows)

0.5.0 (06/28/2016)
-----
* new example (weather PUB/SUB)
* add option to enable IPv6 on sockets
* avoid $DEBUG warnings
* fix specs on Rubinius
* better documentation
* minor CI improvements

0.4.0 (04/13/2016)
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

0.3.0 (04/13/2016)
-----
* port CZTop::Poller to zmq_poller_*() functions so it supports thread-safe
  sockets as well
* extract niche features to CZTop::Poller::Aggregated
* fix taxi system example
* drop support for CZMQ 3.0.2, ZMQ 4.0 and ZMQ 4.1

0.2.1 (01/31/2016)
-----
* improve documentation
* improve test suite

0.2.0 (01/27/2016)
-----
* simplify CZTop::Z85::Padded
  * no length encoding
  * padding similar to PKCS#7
* add utilities `z85encode` and `z85decode`
* add CZTop::Z85::Pipe
* CZTop::SUB#subscribe: subscribe to everything if no parameter given

0.1.1 (01/23/2016)
-----
* add support for Ruby 2.0
* improve documentation
* fix require()s in examples

0.1.0 (01/23/2016)
-----
* first release
