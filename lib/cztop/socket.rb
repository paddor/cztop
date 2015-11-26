module CZTop
  # TODO
  class Socket
    include FFIDelegate
    ffi_delegate :endpoint, :signal, :wait

    def self.new_by_type(type)
      # TODO
    end

    #  Socket types
    module Types
      PAIR   = 0
      PUB    = 1
      SUB    = 2
      REQ    = 3
      REP    = 4
      XREQ   = 5
      XREP   = 6
      PULL   = 7
      PUSH   = 8
      XPUB   = 9
      XSUB   = 10
      DEALER = XREQ
      ROUTER = XREP
      STREAM = 11
    end

    # TODO
    def send(str_or_msg)
      Message.coerce(str_or_msg).send_to(self)
    end
    alias_method :<<, :send

    # TODO
    def receive
      Message.receive_from(self)
    end

    # TODO
    def connect(endpoint)
      ffi_delegate.connect(endpoint)
    end

    # TODO
    def disconnect(endpoint)
      # we can do sprintf in Ruby
      ffi_delegate.disconnect(endpoint, *nil)
    end

    # TODO
    def bind(endpoint)
      ffi_delegate.bind(endpoint)
    end

    # TODO
    def unbind(endpoint)
      # we can do sprintf in Ruby
      ffi_delegate.unbind(endpoint, *nil)
    end

    # TODO
    def options
      Options.new(self)
    end

    # TODO
    def set_option(option, value)
      options.__send__(:"#{option}=", value)
    end
    # TODO
    def get_option(option)
      options.__send__(option.to_sym, value)
    end

    # TODO
    class Options
      # @param zocket [Socket, Actor]
      def initialize(zocket)
        @zocket = zocket
      end
    end

    # TODO
    class REQ < Socket
      def initialize(endpoint)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_req(endpoint))
      end
    end
    # TODO
    class REP < Socket
      def initialize(endpoint)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_rep(endpoint))
      end
    end
    # TODO
    class PAIR < Socket
      def initialize(endpoint=nil)
        attach_ffi_delegate(CZMQ::FFI::Zsock.new_pair(endpoint))
      end
    end
  end
end
