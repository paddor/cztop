# frozen_string_literal: true

require_relative "lib/cztop/version"

Gem::Specification.new do |spec|
  spec.name          = "cztop"
  spec.version       = CZTop::VERSION
  spec.authors       = ["Patrik Wenger"]
  spec.email         = ["paddor@gmail.com"]

  spec.summary       = 'CZMQ FFI binding to bring ZMQ sockets to Ruby'
  spec.description   = 'CZMQ binding based on the generated low-level FFI bindings of CZMQ'
  spec.homepage      = "https://rubygems.org/gems/cztop"
  spec.license       = "ISC"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.0.0")

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/paddor/cztop"
  spec.metadata["changelog_uri"]   = "https://github.com/paddor/cztop/blob/master/CHANGELOG.md"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "czmq-ffi-gen", "~> 1.1.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rspec-given", "~> 3.8.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "rubocop", "~> 1.36.0"
  spec.add_development_dependency "async", ">= 2.0.1"
  spec.add_development_dependency "async-io"
end
