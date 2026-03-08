# frozen_string_literal: true

require 'bundler/setup'
require 'simplecov'
require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/mock'
SimpleCov.start do
  # skip DRAFT API
  add_filter '/lib/cztop/poller.rb'
  add_filter '/lib/cztop/poller/aggregated.rb'
  add_filter '/spec/cztop/poller_spec.rb'
end

require_relative 'zmq_helper'

# Suppress czmq-ffi-gen warnings about unavailable draft functions
original_stderr = $stderr
$stderr = File.open(File::NULL, 'w')
require_relative '../lib/cztop'
$stderr = original_stderr

# Suppress CZMQ C library log messages (e.g. "I: zmonitor: API command=$TERM")
CZMQ::FFI::Zsys.set_logstream(FFI::Pointer::NULL)


if ENV['REPORT_COVERAGE'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end


# NOTE: as of January 28, 2016, the test suite opens about ~650 file
# descriptors. Some OS (like OSX) has a very low default limit of 256. Let's
# raise it to a more sane 1024, like on Linux.
begin
  soft_limit, hard_limit = Process.getrlimit(:NOFILE)
  Process.setrlimit(:NOFILE, 1024, hard_limit) if soft_limit < 1024
rescue NotImplementedError
  # JRuby
end
