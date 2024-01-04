# frozen_string_literal: true

require 'bundler/setup'
require 'simplecov'
require 'rspec'
require 'rspec/given'
SimpleCov.start do
  # skip DRAFT API
  add_filter '/lib/cztop/poller.rb'
  add_filter '/lib/cztop/poller/aggregated.rb'
  add_filter '/spec/cztop/poller_spec.rb'
end

require_relative 'zmq_helper'
require_relative '../lib/cztop'


if ENV['REPORT_COVERAGE'] == 'true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end


RSpec.configure do |config|
  config.expect_with :minitest
  config.filter_run_excluding if: false
  include ZMQHelper
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
