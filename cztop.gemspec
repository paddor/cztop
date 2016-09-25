# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cztop/version'

Gem::Specification.new do |spec|
  spec.name          = "cztop"
  spec.version       = CZTop::VERSION
  spec.authors       = ["Patrik Wenger"]
  spec.email         = ["paddor@gmail.com"]

  spec.summary       = %q{CZMQ Ruby binding, based on the generated low-level FFI bindings of CZMQ}
  spec.homepage      = "https://github.com/paddor/cztop"
  spec.license       = "ISC"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "czmq-ffi-gen", "~> 0.10.0"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rspec-given", "~> 3.8.0"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "guard-yard"
  spec.add_development_dependency "guard-shell"
  spec.add_development_dependency 'terminal-notifier-guard'
  spec.add_development_dependency 'foreman'
end
