require 'bundler/setup'
require 'rspec'
require 'rspec/given'

require_relative '../lib/cztop'

RSpec.configure do |config|
  config.expect_with :minitest
end
