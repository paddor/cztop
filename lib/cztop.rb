require 'czmq-ffi-gen'
require_relative 'cztop/version'

# CZTop tries to provide a complete CZMQ binding with a nice, Ruby-like API.
module CZTop
end

# modules
require_relative 'cztop/has_ffi_delegate'
require_relative 'cztop/zsock_options'
require_relative 'cztop/send_receive_methods'
require_relative 'cztop/polymorphic_zsock_methods'

# CZMQ classes
require_relative 'cztop/actor'
require_relative 'cztop/authenticator'
require_relative 'cztop/beacon'
require_relative 'cztop/certificate'
require_relative 'cztop/config'
require_relative 'cztop/frame'
require_relative 'cztop/message'
require_relative 'cztop/monitor'
require_relative 'cztop/poller'
require_relative 'cztop/proxy'
require_relative 'cztop/socket'
require_relative 'cztop/z85'

# additional
require_relative 'cztop/config/comments'
require_relative 'cztop/config/traversing'
require_relative 'cztop/config/serialization'
require_relative 'cztop/message/frames'
require_relative 'cztop/socket/types'
require_relative 'cztop/z85/padded'
require_relative 'cztop/z85/pipe'


# make Ctrl-C work in case a low-level call hangs
CZMQ::FFI::Signals.disable_default_handling

##
# Probably useless in this Ruby binding:
#
#  * CertificateStore
#  * UUID
#  * Dir
#  * DirPatch
#  * File
#  * HashX
#  * String
#  * Trie
#  * Hash
#  * List

# Implemented before, but removed because useless:
#
#  * Loop
