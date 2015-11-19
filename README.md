cztop
=====

This is a CZMQ Ruby binding, based on the generated low-level FFI bindings from the CZMQ project.

I haven't been able to come up with a better name.

Reasons
-------

* https://github.com/zeromq/czmq low-level FFI bindings for CZMQ, not a gem
* https://github.com/Asmod4n/ruby-ffi-czmq outdated, "abomination" (according to author @Asmod4n)
* https://github.com/methodmissing/rbczmq is a Ruby extension (bad JRuby support)
* https://github.com/chuckremes/ffi-rzmq is for libzmq (low level)
* https://github.com/mtortonesi/ruby-czmq (czmq gem), no tests, outdated

Goals
-----

Here are some some of the goals I have in mind for this library:

* as easy as possible API
* use it to replace the Celluloid::ZMQ part of Celluloid
* encryption made easy, including handling of certificates
* being able to implement some of the missing (CZMQ based) Ruby examples in the ZMQ Guide
* being able to make well-designed reliability patterns from ZMQ Guide ready to use

To Do
-----

* find a better name for this project
  - move code under that project name's module
* think of a neat Ruby API, including:
  - Socket
  - Message
  - Frame
  - Loop or Reactor
  - Authenticator
  - Certificate
  - CertificateStore
  - Config
  - Proxy
  - Z85
    - a portable (FFI) one, as opposed to https://github.com/fpesce/z85
    - probably as an external project
  - Beacon
* specify runnable specs
* write the missing XML API files in CZMQ
  - zcert.xml
  - zcertstore.xml
  - zconfig.xml
* reliability patterns
  - ping-pong (a la http://zguide.zeromq.org/page:all#Heartbeating-for-Paranoid-Pirate)
  - Majordomo
  - Freelance
