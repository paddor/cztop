require 'bundler/setup'
require 'rspec'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'cztop'

RSpec.configure do |config|
  config.expect_with :minitest
end
