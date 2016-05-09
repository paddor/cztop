source 'https://rubygems.org'
gemspec

# useful when working on czmq-ffi-gen in parallel
#gem "czmq-ffi-gen", git: "https://github.com/paddor/czmq-ffi-gen.git"
#gem "rspec-core", git: "file:///Users/paddor/src/ruby/rspec-core"

group :development do
  gem 'rubocop', require: false
  gem 'coveralls', require: false, platform: :mri

  # >= 3.1 doesn't work on Rubinius, see guard/listen#391
  gem 'listen', '~> 3.0.x', require: false
end
