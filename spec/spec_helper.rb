require 'bundler/setup'
require 'rspec'
require 'rspec/given'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'cztop'

RSpec.configure do |config|
  config.expect_with :minitest
end
