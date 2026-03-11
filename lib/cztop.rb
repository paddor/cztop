# frozen_string_literal: true

require_relative 'cztop/ffi'
require_relative 'cztop/version'

# CZTop provides a minimal, focused ZMQ socket library via CZMQ FFI bindings.
#
module CZTop
end

# modules
require_relative 'cztop/has_ffi_delegate'
require_relative 'cztop/zsock_options'

# Socket base class + mixins
require_relative 'cztop/socket'
require_relative 'cztop/socket/fd_wait'
require_relative 'cztop/socket/readable'
require_relative 'cztop/socket/writable'

# Socket types
require_relative 'cztop/socket/types'
require_relative 'cztop/socket/req'
require_relative 'cztop/socket/rep'
require_relative 'cztop/socket/dealer'
require_relative 'cztop/socket/router'
require_relative 'cztop/socket/pub'
require_relative 'cztop/socket/sub'
require_relative 'cztop/socket/xpub'
require_relative 'cztop/socket/xsub'
require_relative 'cztop/socket/push'
require_relative 'cztop/socket/pull'
require_relative 'cztop/socket/pair'
require_relative 'cztop/socket/stream'
