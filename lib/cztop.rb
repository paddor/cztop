lib = File.expand_path('../../vendor/czmq/bindings/ruby/lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'czmq/ffi'

module CZMQ
  ##
  # Essential.
  #
  class Socket
  end
  class Message
  end
  class Frame
  end


  ##
  # Probably useful.
  #

  class Actor
  end
  class Loop
  end
  class Poller
  end
  class UUID
  end

  ##
  # Would be nice, but low-level FFI bindings don't exist yet.
  #

#  class Config
#  end
#  class Authenticator
#  end
#  class Certificate
#  end


  ##
  # Probably useless in this Ruby binding.
  #

#  class Dir
#  end
#  class DirPatch
#  end
#  class File
#  end
#  class HashX
#  end
#  class String
#  end
#  class Trie
#  end
#  class Hash
#  end
#  class List
##  end
end

CZMQ::FFI.available? or raise LoadError, "libczmq is not available"
