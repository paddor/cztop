lib = File.expand_path('../vendor/czmq/bindings/ruby/lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'czmq/ffi'
