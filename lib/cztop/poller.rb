module CZTop
  # CZMQ poller, a trivial socket poller. This only supports polling for
  # reading, and only on (CZMQ) {Socket}s and {Actor}s (well, and "raw" ZMQ
  # sockets).
  #
  # @see http://api.zeromq.org/czmq3-0:zpoller
  class Poller
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ::CZMQ::FFI

    # Used for various {Poller} errors.
    class Error < RuntimeError; end

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
    # @raise [Error] if this fails
    def add(reader)
      rc = ffi_delegate.add(reader)
      raise Error, "unable to add socket %p" % reader if rc == -1
      remember_socket(reader)
    end

    # Removes a reader socket from the poller.
    # @param reader [Socket, Actor] socket to remove
    # @return [void]
    # @raise [Error] if this fails (e.g. if socket wasn't registered in
    #   this poller)
    def remove(reader)
      rc = ffi_delegate.remove(reader)
      raise Error, "unable to remove socket %p" % reader if rc == -1
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
    # @param flag [Boolean] whether
    def nonstop=(flag)
      ffi_delegate.set_nonstop(flag)
    end

    private

    # Remembers the socket so a call to {#wait} can return with the exact same
    # instance of {Socket}, and it also makes sure the socket won't get
    # GC'd.
    # @param [Socket, Actor] the socket instance to remember
    # @return [void]
    def remember_socket(socket)
      @sockets[socket.to_ptr.to_i] = socket
    end

    # Forgets the socket because it has been removed from the poller.
    # @param [Socket, Actor] the socket instance to forget
    # @return [void]
    def forget_socket(socket)
      @sockets.delete(socket.to_ptr.to_i)
    end

    # Gets the previously remembered socket associated to the given pointer.
    # @param ptr [FFI::Pointer] the pointer to a socket
    # @return [Socket, Actor] the socket associated to the given pointer
    # @raise [ArgumentError] if no socket is registered under given pointer
    def socket_by_ptr(ptr)
      @sockets[ptr.to_i] or
        # NOTE: This should never happen, since #wait will return nil if
        # +zpoller_wait+ returned NULL. But it's better to fail early in case
        # it ever returns a wrong pointer.
        raise Error, "no socket known for pointer #{ptr.inspect}"
    end
  end
end
