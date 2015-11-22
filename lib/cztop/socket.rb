module CZTop
  class Socket

    def self.new_by_type(type)
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

    include NativeDelegate
    native_delegate :endpoint, :signal, :wait

    def send(str_or_msg)
      str_or_msg = Message.coerce(str_or_msg)
      str_or_msg.send_to(self)
    end
    alias_method :<<, :send

    def receive
    end

#    def send_string(str)
#      str = String str
#      @delegate.send("b", :string, str, :size_t, str.bytesize)
#    end
#    def receive_string
#      @delegate.recv("b")
#    end

    def connect(endpoint)
      @delegate.connect(endpoint)
    end

    def disconnect(endpoint)
      # we can do sprintf in Ruby
      @delegate.disconnect(endpoint, *nil)
    end

    def bind(endpoint)
      @delegate.bind(endpoint)
    end

    def unbind(endpoint)
      # we can do sprintf in Ruby
      @delegate.unbind(endpoint, *nil)
    end

    class REQ < Socket
      def initialize(endpoint)
        self.delegate = CZMQ::FFI::Zsock.new_req(endpoint)
      end
    end
    class REP < Socket
      def initialize(endpoint)
        self.delegate = CZMQ::FFI::Zsock.new_rep(endpoint)
      end
    end
    class PAIR < Socket
      def initialize(endpoint=nil)
        self.delegate = CZMQ::FFI::Zsock.new_pair(endpoint)
      end
    end
  end
end
