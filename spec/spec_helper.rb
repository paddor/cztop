require 'bundler/setup'
if RUBY_ENGINE == "ruby"
  # no need for additional coverage reports on other Rubies. Doesn't seem to
  # work on JRuby anyway.
  require 'coveralls'
  Coveralls.wear!
end
require 'rspec'
require 'rspec/given'

require_relative 'czmq_helper'
require_relative '../lib/cztop'

RSpec.configure do |config|
  config.expect_with :minitest
  include CZMQHelper
end
