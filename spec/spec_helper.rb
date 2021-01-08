require 'bundler/setup'

# Avoid additional coverage reports on other Rubies.
if RUBY_ENGINE == "ruby"

  # avoid additional coverage reports on other MRI versions
  main_version = File.read(File.expand_path('../../.ruby-version', __FILE__)).chomp

  if RUBY_VERSION.start_with? main_version
    require 'coveralls'
    Coveralls.wear!
  end
end
require 'rspec'
require 'rspec/given'

require_relative 'zmq_helper'
require_relative '../lib/cztop'

RSpec.configure do |config|
  config.expect_with :minitest
  config.filter_run_excluding if: false
  include ZMQHelper
end

# NOTE: as of January 28, 2016, the test suite needs opens about ~650 file
# descriptors. Some OS (like OSX) has a very low default limit of 256. Let's
# raise it to a more sane 1024, like on Linux.
begin
  soft_limit, hard_limit = Process.getrlimit(:NOFILE)
  if soft_limit < 1024
    Process.setrlimit(:NOFILE, 1024, hard_limit)
  end
rescue NotImplementedError
  # JRuby
end
