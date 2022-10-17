# frozen_string_literal: true

module CZTop
  # This is the trivial poller based on zpoller. It only supports polling
  # for readability, but it also supports doing that on CLIENT/SERVER sockets,
  # which is useful for {CZTop::Poller}.
  #
  # @see http://api.zeromq.org/czmq3-0:zpoller
  class Poller::ZPoller
    include HasFFIDelegate
    extend CZTop::HasFFIDelegate::ClassMethods
    include ::CZMQ::FFI

    # Initializes the Poller. At least one reader has to be given.
    # @param reader [Socket, Actor] socket to poll for input
    # @param readers [Socket, Actor] any additional sockets to poll for input
    def initialize(reader, *readers)
      @sockets = {} # to keep references and return same instances
      ptr      = Zpoller.new(reader,
                             *readers.flat_map { |r| [:pointer, r] },
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
      raise_zmq_err(format('unable to add socket %p', reader)) if rc == -1
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
      raise_zmq_err(format('unable to remove socket %p', reader)) if rc == -1
      forget_socket(reader)
    end


    # Waits and returns the first socket that becomes readable.
    # @param timeout [Integer] how long to wait in ms, or 0 to avoid
    #   blocking, or -1 to wait indefinitely
    # @return [Socket, Actor] first socket of interest
    # @return [nil] if the timeout expired or
    # @raise [Interrupt] if the timeout expired or
    def wait(timeout = -1)
      ptr = ffi_delegate.wait(timeout)
      if ptr.null?
        raise Interrupt if ffi_delegate.terminated

        return nil
      end
      socket_by_ptr(ptr)
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
