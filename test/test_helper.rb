# frozen_string_literal: true

require 'bundler/setup'
require 'simplecov'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/mock'
SimpleCov.start

require_relative 'zmq_helper'

require_relative '../lib/cztop'

# Suppress CZMQ C library log messages (e.g. "I: zmonitor: API command=$TERM")
CZMQ::FFI::Zsys.set_logstream(FFI::Pointer::NULL)

# Use a shorter FD_TIMEOUT in tests to reduce fiber scheduler latency
# in timing-sensitive async tests.
CZTop::Socket::FdWait.send(:remove_const, :FD_TIMEOUT)
CZTop::Socket::FdWait::FD_TIMEOUT = 0.05


# NOTE: as of January 28, 2016, the test suite opens about ~650 file
# descriptors. Some OS (like OSX) has a very low default limit of 256. Let's
# raise it to a more sane 1024, like on Linux.
begin
  soft_limit, hard_limit = Process.getrlimit(:NOFILE)
  Process.setrlimit(:NOFILE, 1024, hard_limit) if soft_limit < 1024
rescue NotImplementedError
  # JRuby
end
