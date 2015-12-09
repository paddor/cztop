require 'bundler/setup'
require 'coveralls'; Coveralls.wear!
require 'rspec'
require 'rspec/given'

require_relative '../lib/cztop'

RSpec.configure do |config|
  config.expect_with :minitest
end
