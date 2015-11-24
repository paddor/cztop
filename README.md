# CZTop

This is a CZMQ Ruby binding, based on the generated low-level FFI bindings from the CZMQ project.

## Reasons

* low-level FFI bindings of [zeromq/czmq](https://github.com/zeromq/czmq)
  * I love the idea because they're generated
  * but they were in a very bad state (much better now, of course)
* [Asmod4n/ruby-ffi-czmq](https://github.com/Asmod4n/ruby-ffi-czmq)
  * outdated
  * "abomination" according its author
* [methodmissing/rbczmq](https://github.com/methodmissing/rbczmq)
  * no JRuby support (see methodmissing/rbczmq#48)
  * no support for security features (see methodmissing/rbczmq#28)
* [mtortonesi/ruby-czmq](https://github.com/mtortonesi/ruby-czmq)
  * no tests
  * outdated
* [chuckremes/ffi-rzmq](https://github.com/chuckremes/ffi-rzmq)
  * low level ZMQ gem, not CZMQ

## Goals

Here are some some of the goals I have in mind for this library:

* as easy as possible API
* first class support for security (CURVE mechanism)
* support MRI, Rubinius, and JRuby
* use it to replace the Celluloid::ZMQ part of Celluloid
* encryption made easy, including handling of certificates
* being able to implement some of the missing (CZMQ based) Ruby examples in the ZMQ Guide
* being able to make well-designed reliability patterns from ZMQ Guide ready to use

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'cztop'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cztop

## Usage

TODO: Write usage instructions here

## TODO

* maybe find a better name for this project
* think of a neat Ruby API, including:
  - Actor
  - Socket
    - Options to encapsulate all option setters and getters
  - Message
  - Frame
    - enumerable Frames
  - Loop
  - Authenticator
  - Certificate
  - CertificateStore
  - Config
  - Proxy
  - Z85
    - a portable (FFI) one, as opposed to [fpesce/z85](https://github.com/fpesce/z85)
  - Beacon
* specify runnable specs
* write the missing XML API files in CZMQ
  - zcertstore.xml
  - zconfig.xml
* reliability patterns (in another project, or have a closer look at Malamute/MLDP)
  - ping-pong (a la http://zguide.zeromq.org/page:all#Heartbeating-for-Paranoid-Pirate)
  - Majordomo
  - Freelance

## License

The gem is available as open source under the terms of the [ISC License](http://opensource.org/licenses/ISC).
See the LICENSE file.
