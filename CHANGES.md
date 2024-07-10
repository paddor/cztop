1.2.5 (7/11/2024)
-----
* CZTop::Socket::ROUTER#wait_writable: don't raise SocketError if no peer is connected
    - even if ZMQ_ROUTER_MANDATORY is set
    - this can be used to wait for connected peers
    - set a #sndtimeo if you want a an exception
* CZTop::Socket::CLIENT#wait_writable: don't raise SocketError if no peer is connected
    - this can be used to wait for connected peers
    - set a #sndtimeo if you want a an exception
* CZTop::ZsockOptions#[] and #[]=: avoid calling #public_methods if possible

1.2.4 (1/16/2024)
-----
* PolymorphicZsockMethods#wait: fail with NotImplementedError inside non-blocking Fibers
* fail with ArgumentError when sending message with no parts

1.2.3 (1/7/2024)
-----
* no changes, just re-release to update README on https://www.rubydoc.info/gems/cztop

1.2.2 (1/7/2024)
-----
* restore compatibility with Ruby 3.0+
* fix latency issue

1.2.1 (1/7/2024)
-----
* fix changelog URI

1.2.0 (1/7/2024)
-----
* refactor waiting for socket readability/writability
* fix ROUTER socket hanging in busy loop if ZMQ_ROUTER_MANDATORY flag is set and sending a message while no peers are connected
* same for unconnected CLIENT sockets
* slim down packaged gem
* modernize examples
* require Ruby 3.2
* some exceptions changed from EAGAIN to IO::TimeoutError
* Certificate.load and .new_from raise NotImplementedError if CURVE is not available

1.1.2 (1/5/2024)
-----
* refactor to make code Fiber Scheduler agnostic
* remove Async::IO::CZTopSocket

1.1.1 (1/4/2024)
-----
* speed up Async::IO#wait_readable and #wait_writable
* update CI and specs

1.1.0 (1/4/2024)
-----
* support Async

1.1.0.pre1 (10/17/2022)
-----
* modernize syntax using Rubocop
* use czmq-ffi-gen 1.1.0.pre1
* require Ruby >= 2.7.x

1.0.0 (01/08/2021)
-----
* use czmq-ffi-gen 1.0.x
* modernized project

0.13.1 (03/04/2018)
-----
* fix specs

0.13.0 (03/04/2018)
-----
* use czmq-ffi-gen 0.15.x
* CZTop::Monitor#listen: removed HANDSHAKE_FAILED and HANDSHAKE_SUCCEED events
  and added HANDSHAKE_SUCCEEDED, HANDSHAKE_FAILED_NO_DETAIL,
  HANDSHAKE:FAILED_PROTOCOL, HANDSHAKE_FAILED_AUTH to reflect changes in CZMQ
* add CZTop::Monitor#fd and #readable?
* add CZTop::ZsockOptions#fd (so #fd can be called on Sockets and Actors directly)
* CZTop::Message#to_a: create less intermediate objects
* support ZMQ_RECONNECT_IVL option
* CZTop::Frame#group: return nil if group string is empty

0.12.2 (11/24/2017)
-----
* no changes, but this release includes an up-to-date version of this file

0.12.1 (11/23/2017)
-----
* actually include the change for CZTop::Poller#wait documented in 0.12.0
* more robust specs around CZTop::Monitor
* test recent rubies on CI

0.12.0 (11/23/2017)
-----
* CZTop::Monitor#listen: accept HANDSHAKE_FAILED and HANDSHAKE_SUCCEED events
* remove shim classes for IO::EAGAINWaitWritable and IO::EAGAINWaitReadable
  missing in Ruby < 2.1
* CZTop::Poller#wait: handle new error EAGAIN (was ETIMEDOUT) from zmq_poller_wait()

0.11.4 (01/06/2017)
-----
* Socket#inspect: don't raise if native object has been destroyed

0.11.3 (01/02/2017)
-----
* upgrade to czmq-ffi-gen's 0.13.x line

0.11.2 (11/16/2016)
-----
* ZsockOptions#identity=: instead of asserting in CZMQ, raise ArgumentError if
  identity is invalid

0.11.1 (11/16/2016)
-----
* Metadata.load: check for incomplete property names and values

0.11.0 (11/06/2016)
-----
* upgrade to czmq-ffi-gen's 0.12.x line (which includes the CZMQ v4.0.0 release)
* add support for RADIO/DISH and SCATTER/GATHER sockets
* add CZTop::Frame#group and #group= methods
* add CZTop::Metadata to encode/decode ZMTP metadata

0.10.0 (10/24/2016)
-----
* add Socket#readable? and #writable?
* Socket#options: memoize the OptionAccessor instance

0.9.4 (10/22/2016)
-----
* Beacon#configure: correctly handle interrupt, and fix API doc

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
* port CZTop::Poller to `zmq_poller_*()` functions so it supports thread-safe
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
