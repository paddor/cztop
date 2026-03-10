# frozen_string_literal: true

require_relative 'cztop/ffi'
require_relative 'cztop/version'

# CZTop tries to provide a complete CZMQ binding with a nice, Ruby-like API.
module CZTop
end

# modules
require_relative 'cztop/has_ffi_delegate'
require_relative 'cztop/zsock_options'
require_relative 'cztop/polymorphic_zsock_methods'

# Socket base class + mixins
require_relative 'cztop/socket'
require_relative 'cztop/socket/fd_wait'
require_relative 'cztop/socket/readable'
require_relative 'cztop/socket/writable'

# CZMQ classes
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
require_relative 'cztop/actor'
require_relative 'cztop/authenticator'
require_relative 'cztop/beacon'
require_relative 'cztop/certificate'
require_relative 'cztop/cert_store'
require_relative 'cztop/config'
require_relative 'cztop/monitor'
require_relative 'cztop/proxy'
require_relative 'cztop/z85'

# additional
require_relative 'cztop/config/comments'
require_relative 'cztop/config/traversing'
require_relative 'cztop/config/serialization'
require_relative 'cztop/metadata'
require_relative 'cztop/z85/padded'
require_relative 'cztop/z85/pipe'
require_relative 'cztop/zap'
