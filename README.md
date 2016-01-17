[![Build Status on Travis CI](https://travis-ci.org/paddor/cztop.svg?branch=master)](https://travis-ci.org/paddor/cztop?branch=master)
[![Code Climate](https://codeclimate.com/repos/56677a7849f50a141c001784/badges/48f3cca3c62df9e4b17b/gpa.svg)](https://codeclimate.com/repos/56677a7849f50a141c001784/feed)
[![Inline docs](http://inch-ci.org/github/paddor/cztop.svg?branch=master&style=shields)](http://inch-ci.org/github/paddor/cztop)
[![Dependency Status](https://gemnasium.com/paddor/cztop.svg)](https://gemnasium.com/paddor/cztop)
[![Coverage Status](https://coveralls.io/repos/paddor/cztop/badge.svg?branch=master&service=github)](https://coveralls.io/github/paddor/cztop?branch=master)

# CZTop

```
_________  _____________________
\_   ___ \ \____    /\__    ___/____  ______
/    \  \/   /     /   |    |  /  _ \ \____ \
\     \____ /     /_   |    | (  <_> )|  |_> >
 \______  //_______ \  |____|  \____/ |   __/
        \/         \/                 |__|
```

CZTop is a CZMQ Ruby binding. It is based on
[czmq-ffi-gen](https://github.com/paddor/czmq-ffi-gen), the generated low-level
FFI binding of [CZMQ](https://github.com/zeromq/czmq) and has a focus on being
easy to use for Rubyists (POLS) and providing first class support for security
mechanisms (like CURVE).

## Reasons

Why another CZMQ Ruby binding? Here is a list of existing projects I found and
the issues with them, from my point of view:

* [Asmod4n/ruby-ffi-czmq](https://github.com/Asmod4n/ruby-ffi-czmq)
  * outdated
  * according to its author, it's an "abomination"
* [methodmissing/rbczmq](https://github.com/methodmissing/rbczmq)
  * no support for security features (see [methodmissing/rbczmq#28](https://github.com/methodmissing/rbczmq/issues/28))
  * no JRuby support (see [methodmissing/rbczmq#48](https://github.com/methodmissing/rbczmq/issues/48))
  * doesn't feel like Ruby
* [mtortonesi/ruby-czmq](https://github.com/mtortonesi/ruby-czmq)
  * no tests
  * outdated
  * doesn't feel like Ruby
* [chuckremes/ffi-rzmq](https://github.com/chuckremes/ffi-rzmq)
  * low level ZMQ gem, not CZMQ

Furthermore, I knew about the generated low-level Ruby FFI binding in the
[zeromq/czmq](https://github.com/zeromq/czmq) repository. I wanted to make use
of them because I love that they're generated (and thus, most likely correct
and up-to-date). Unfortunately, they were in pretty bad shape and missing a few
CZMQ classes.

So I decided to improve the quality and usability of the binding and add the
missing classes. The result is
[czmq-ffi-gen](https://github.com/paddor/czmq-ffi-gen) which provides a solid
foundation for CZTop.

## Goals

Here are some some of the goals I have/had in mind for this library:

- [x] as easy as possible, Ruby-esque API
- [x] first class support for security (CURVE mechanism)
  - [x] including handling of certificates
- [x] support MRI, Rubinius, and JRuby
- [x] high-quality API documentation
- [x] 100% test coverage
- [x] provide a portable Z85 implementation
  * unlike [fpesce/z85](https://github.com/fpesce/z85), which is a C extension
- [ ] use it to replace the [Celluloid::ZMQ](https://github.com/celluloid/celluloid-zmq) part of [Celluloid](https://github.com/celluloid/celluloid)
- [ ] implement some of the missing (CZMQ based) Ruby examples in the [ZMQ Guide](http://zguide.zeromq.org/page:all)

## Installation

This gem requires the presence of the CZMQ library, which in turn requires the
ZMQ library. For **security mechanisms** like CURVE, you'll need
[libsodium](https://github.com/jedisct1/libsodium) and at least ZMQ 4.0.

On OSX using homebrew, run:

    $ brew install libsodium
    $ brew install zmq --with-libsodium
    $ brew install czmq

If you're running Linux, go check [this page](http://zeromq.org/distro:_start)
to get more help. Make sure to install CZMQ, not only ZMQ.

To then use this gem, add this line to your application's Gemfile:

```ruby
gem 'cztop'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cztop

## Usage

See the examples directory for some examples. Here's a very simple one:

```ruby
# TODO: Simple PAIR socket example.
```

## Supported Ruby versions

See [.travis.yml](.travis.yml) for a list of Ruby versions against which CZTop
is tested.

## Documentation

The API should be fairly straight-forward to anyone who is familiar with CZMQ
and Ruby.  The following API documentation is currently available:

* [YARD API documentation](http://www.rubydoc.info/github/paddor/cztop)

Feel free to start a [wiki](https://github.com/paddor/cztop/wiki) page.

## TODO

* [x] pack generated code into its own gem (czmq-ffi-gen)
* think of a neat Ruby API, including:
  - [x] Actor
  - [x] Beacon
  - [x] Certificate
  - [x] Socket
    - [50%] access to all socket options
    - [x] Security mechanisms
  - [x] Message
  - [x] Frame
    - [x] enumerable Frames
  - [x] Authenticator
  - [x] Loop
  - [x] Monitor
  - [x] Poller
  - [x] Proxy
  - [x] Config
  - [x] Z85
* write the missing XML API files in CZMQ
  - [x] zarmour.xml
  - [x] zconfig.xml
  - [x] zsock_option.xml
  - [x] zcert.xml
  - [x] zcertstore.xml
* [x] check availability of libsodium within CZTop
* [x] read error strings for exceptions where appropriate (zmq_strerror)
* [x] add support for ZMTP 3.1 heartbeats in CZMQ
* [ ] add more examples
* [ ] add performance benchmarks

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/paddor/cztop.

To run the tests before/after you made any changes to the source and have
created a test case for it, use `rake spec`.

## License

The gem is available as open source under the terms of the [ISC License](http://opensource.org/licenses/ISC).
See the [LICENSE](https://github.com/paddor/cztop/blob/master/LICENSE) file.
