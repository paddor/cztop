lib = File.expand_path('../../vendor/czmq/bindings/ruby/lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'czmq/ffi'
require 'forwardable'
require 'cztop/version'

CZMQ::FFI.available? or raise LoadError, "libczmq is not available"

module CZTop
  class InitializationError < ::FFI::NullPointerError; end
end

# Helpers of this binding
require_relative 'cztop/native_delegate'

# CZMQ classes
require_relative 'cztop/actor'
require_relative 'cztop/certificate'
require_relative 'cztop/certificate_store'
require_relative 'cztop/config'
require_relative 'cztop/frame'
require_relative 'cztop/message'
require_relative 'cztop/proxy'
require_relative 'cztop/socket'
require_relative 'cztop/loop'
require_relative 'cztop/z85'


##
# Probably useless in this Ruby binding.
#
#  class Poller; end
#  class UUID; end
#  class Dir; end
#  class DirPatch; end
#  class File; end
#  class HashX; end
#  class String; end
#  class Trie; end
#  class Hash; end
#  class List; end
