module CZTop
  # A non-trivial socket poller.
  #
  # It can poll for reading and writing, and supports getting back an array of
  # readable/writable sockets after the call to {#wait}. The reason for this
  # feature is to be able to use it in Celluloid::ZMQ, where in a call to
  # Celluloid::ZMQ::Reactor#run_once all readable/writable sockets need to be
  # processed.
  #
  # This implementation is NOT based on zpoller. Reasons:
  #
  # * zpoller can only poll for reading
  #
  # It's also NOT based on `zmq_poller()`. Reasons:
  #
  # * zmq_poller() doesn't exist in older versions of ZMQ < 4.2
  #
  # Possible future implementation on +zmq_poller()+ might work like this, to
  # support getting an array of readable/writable sockets:
  #
  # * in {#wait}, poll with normal timeout
  # * then poll again with zero timeout until no more sockets, accumulate
  #   results
  #
  # = Limitations
  #
  # This poller can't poll for writing on CLIENT/SERVER sockets.
  # Implementation could be adapted to support them using
  # {CZTop::Poller::ZPoller}, at least for reading. But it'd make the code
  # ugly.
  #
  class Poller
    # CZTop's interface to the low-level +zmq_poll()+ function.
    module ZMQ

      POLL    = 1
      POLLIN  = 1
      POLLOUT = 2
      POLLERR = 4

      extend ::FFI::Library
      lib_name = 'libzmq'
      lib_paths = ['/usr/local/lib', '/opt/local/lib', '/usr/lib64']
        .map { |path| "#{path}/#{lib_name}.#{::FFI::Platform::LIBSUFFIX}" }
      ffi_lib lib_paths + [lib_name]

      # Represents a struct of type +zmq_pollitem_t+.
      class PollItem < FFI::Struct
        ##
        # shamelessly taken from https://github.com/mtortonesi/ruby-czmq-ffi
        #


        FD_TYPE = if FFI::Platform::IS_WINDOWS && FFI::Platform::ADDRESS_SIZE == 64
          # On Windows, zmq.h defines fd as a SOCKET, which is 64 bits on x64.
          :uint64
        else
          :int
        end

        layout  :socket,  :pointer,
                :fd,      FD_TYPE,
                :events,  :short,
                :revents, :short

        # @return [Boolean] whether the socket is readable
        def readable?
          (self[:revents] & POLLIN) > 0
        end

        # @return [Boolean] whether the socket is writable
        def writable?
          (self[:revents] & POLLOUT) > 0
        end
      end

      opts = {
        blocking: true  # only necessary on MRI to deal with the GIL.
      }

      #ZMQ_EXPORT int  zmq_poll (zmq_pollitem_t *items, int nitems, long timeout);
      attach_function :poll, :zmq_poll, [:pointer, :int, :long], :int, **opts
    end

    # @param readers [Socket, Actor] sockets to poll for input
    def initialize(*readers)
      @readers = {}
      @writers = {}
      @readable = []
      @writable = []
      @rebuild_needed = true
      readers.each { |r| add_reader(r) }
    end

    # @return [Array<CZTop::Socket>] registered reader sockets
    def readers
      @readers.values
    end

    # @return [Array<CZTop::Socket>] registered writer sockets
    def writers
      @writers.values
    end

    # Adds a socket to be polled for reading.
    # @param socket [CZTop::Socket] the socket
    # @return [void]
    def add_reader(socket)
      ptr = CZMQ::FFI::Zsock.resolve(socket) # get low-level handle
      @readers[ptr.to_i] = socket
      @rebuild_needed = true
    end

    # Removes a previously registered reader socket. Won't raise if you're
    # trying to remove a socket that's not registered.
    # @param socket [CZTop::Socket] the socket
    # @return [void]
    def remove_reader(socket)
      ptr = CZMQ::FFI::Zsock.resolve(socket) # get low-level handle
      @readers.delete(ptr.to_i) and @rebuild_needed = true
    end

    # Adds a socket to be polled for writing.
    # @param socket [CZTop::Socket] the socket
    # @return [void]
    def add_writer(socket)
      ptr = CZMQ::FFI::Zsock.resolve(socket) # get low-level handle
      @writers[ptr.to_i] = socket
      @rebuild_needed = true
    end

    # Removes a previously registered writer socket. Won't raise if you're
    # trying to remove a socket that's not registered.
    # @param socket [CZTop::Socket] the socket
    # @return [void]
    def remove_writer(socket)
      ptr = CZMQ::FFI::Zsock.resolve(socket) # get low-level handle
      @writers.delete(ptr.to_i) and @rebuild_needed = true
    end

    # Waits for registered sockets to become readable or writable, depending
    # on what you're interested in.
    #
    # @param timeout [Integer] how long to wait in ms, or 0 to avoid blocking,
    #   or -1 to wait indefinitely
    # @return [Socket, Actor] the first readable socket
    # @return [nil] if the timeout expired or
    # @raise [Interrupt] if the timeout expired or
    def wait(timeout = -1)
      rebuild if @rebuild_needed
      @readable = @writable = nil

      num = ZMQ.poll(@items_ptr, @nitems, timeout)
      HasFFIDelegate.raise_zmq_err if num == -1

      return nil if num == 0
      return readable[0] if readable.any?

      # TODO: handle CLIENT/SERVER sockets using ZPoller
#      if threadsafe_sockets.any?
#        zpoller.wait(0)
#      end
    end

    # @return [Array<CZTop::Socket>] readable sockets (memoized)
    def readable
      @readable ||= @reader_items.select(&:readable?).map do |item|
        ptr = item[:socket]
        @readers[ ptr.to_i ]
      end
    end

    # @return [Array<CZTop::Socket>] writable sockets (memoized)
    def writable
      @writable ||= @writer_items.select(&:writable?).map do |item|
        ptr = item[:socket]
        @writers[ ptr.to_i ]
      end
    end

    private

    # Rebuilds the list of `poll_item_t`.
    # @return [void]
    def rebuild
      @nitems = @readers.size + @writers.size
      @items_ptr = FFI::MemoryPointer.new(ZMQ::PollItem, @nitems)
      @items_ptr.autorelease = true

      # memory addresses
      mem = Enumerator.new do |y|
        @nitems.times { |i| y << @items_ptr + i * ZMQ::PollItem.size }
      end

      @reader_items = @readers.map{|_,s| new_item(mem.next, s, ZMQ::POLLIN) }
      @writer_items = @writers.map{|_,s| new_item(mem.next, s, ZMQ::POLLOUT) }

      @rebuild_needed = false
    end

    # @param address [FFI::Pointer] allocated memory address for this item
    # @param socket [CZTop::Socket] socket we're interested in
    # @param events [Integer] the events we're interested in
    # @return [ZMQ::PollItem] a new item for
    def new_item(address, socket, events)
      item = ZMQ::PollItem.new(address)
      item[:socket] = CZMQ::FFI::Zsock.resolve(socket)
      item[:fd] = 0
      item[:events] = events
      item[:revents] = 0
      item
    end

    # This is the trivial poller based on zpoller. It only supports polling
    # for reading, but it also supports doing that on CLIENT/SERVER sockets,
    # which is useful for {CZTop::Poller}.
    #
    # @see http://api.zeromq.org/czmq3-0:zpoller
    class ZPoller
      include HasFFIDelegate
      extend CZTop::HasFFIDelegate::ClassMethods
      include ::CZMQ::FFI

      # Initializes the Poller. At least one reader has to be given.
      # @param reader [Socket, Actor] socket to poll for input
      # @param readers [Socket, Actor] any additional sockets to poll for input
      def initialize(reader, *readers)
        @sockets = {} # to keep references and return same instances
        ptr = Zpoller.new(reader,
                          *readers.flat_map {|r| [ :pointer, r ] },
                          :pointer, nil)
        attach_ffi_delegate(ptr)
        remember_socket(reader)
        readers.each { |r| remember_socket(r) }
      end

      # Adds another reader socket to the poller.
      # @param reader [Socket, Actor] socket to poll for input
      # @return [void]
      # @raise [SystemCallError] if this fails
      def add(reader)
        rc = ffi_delegate.add(reader)
        raise_zmq_err("unable to add socket %p" % reader) if rc == -1
        remember_socket(reader)
      end

      # Removes a reader socket from the poller.
      # @param reader [Socket, Actor] socket to remove
      # @return [void]
      # @raise [ArgumentError] if socket was invalid, e.g. it wasn't registered
      #   in this poller
      # @raise [SystemCallError] if this fails for another reason
      def remove(reader)
        rc = ffi_delegate.remove(reader)
        raise_zmq_err("unable to remove socket %p" % reader) if rc == -1
        forget_socket(reader)
      end

      # Wait and return the first socket that becomes readable.
      # @param timeout [Integer] how long to wait in ms, or 0 to avoid blocking,
      #   or -1 to wait indefinitely
      # @return [Socket, Actor]
      # @return [nil] if the timeout expired or
      # @raise [Interrupt] if the timeout expired or
      def wait(timeout = -1)
        ptr = ffi_delegate.wait(timeout)
        if ptr.null?
          raise Interrupt if ffi_delegate.terminated
          return nil
        end
        return socket_by_ptr(ptr)
      end

      # Tells the zpoller to ignore interrupts. By default, {#wait} will return
      # immediately if it detects an interrupt (when +zsys_interrupted+ is set
      # to something other than zero). Calling this method will supress this
      # behavior.
      # @return [void]
      def ignore_interrupts
        ffi_delegate.ignore_interrupts
      end

      # By default the poller stops if the process receives a SIGINT or SIGTERM
      # signal. This makes it impossible to shut-down message based architectures
      # like zactors. This method lets you switch off break handling. The default
      # nonstop setting is off (false).
      #
      # Setting this will cause {#wait} to never raise.
      #
      # @param flag [Boolean] whether the poller should run nonstop
      def nonstop=(flag)
        ffi_delegate.set_nonstop(flag)
      end

      private

      # Remembers the socket so a call to {#wait} can return with the exact same
      # instance of {Socket}, and it also makes sure the socket won't get
      # GC'd.
      # @param socket [Socket, Actor] the socket instance to remember
      # @return [void]
      def remember_socket(socket)
        @sockets[socket.to_ptr.to_i] = socket
      end

      # Forgets the socket because it has been removed from the poller.
      # @param socket [Socket, Actor] the socket instance to forget
      # @return [void]
      def forget_socket(socket)
        @sockets.delete(socket.to_ptr.to_i)
      end

      # Gets the previously remembered socket associated to the given pointer.
      # @param ptr [FFI::Pointer] the pointer to a socket
      # @return [Socket, Actor] the socket associated to the given pointer
      # @raise [SystemCallError] if no socket is registered under given pointer
      def socket_by_ptr(ptr)
        @sockets[ptr.to_i] or
          # NOTE: This should never happen, since #wait will return nil if
          # +zpoller_wait+ returned NULL. But it's better to fail early in case
          # it ever returns a wrong pointer.
          raise_zmq_err("no socket known for pointer #{ptr.inspect}")
      end
    end
  end
end
