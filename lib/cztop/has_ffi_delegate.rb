# frozen_string_literal: true

require 'forwardable'
require 'socket' # for SocketError

# This module is used to attach the low-level objects of classes within the
# CZMQ::FFI namespace (coming from the _czmq-ffi-gen_ gem) as delegates.
module CZTop::HasFFIDelegate
  # @return [CZMQ::FFI::*] the attached delegate
  attr_reader :ffi_delegate

  # @return [FFI::Pointer] FFI delegate's pointer
  def to_ptr
    @ffi_delegate.to_ptr
  end


  # Attaches an FFI delegate to the current (probably new) {CZTop} object.
  # @param ffi_delegate an instance of the corresponding class in the
  #   CZMQ::FFI namespace
  # @raise [SystemCallError, ArgumentError, ...] if the FFI delegate's
  #   internal pointer is NULL
  # @return [void]
  # @note This only raises the correct exception when the creation of the new
  #   CZMQ object was the most recent thing done with the CZMQ library and
  #   thus CZMQ::FFI::Errors.errno is still reports the correct error number.
  # @see raise_zmq_err
  def attach_ffi_delegate(ffi_delegate)
    raise_zmq_err(CZMQ::FFI::Errors.strerror) if ffi_delegate.null?
    @ffi_delegate = ffi_delegate
  end


  # Same as the counterpart in {ClassMethods}, but usable from within an
  # instance.
  # @see CZTop::FFIDelegate::ClassMethods#from_ffi_delegate
  # @return [CZTop::*] the new object
  def from_ffi_delegate(ffi_delegate)
    self.class.from_ffi_delegate(ffi_delegate)
  end

  module_function

  # Raises the appropriate exception for the reported ZMQ error.
  #
  # @param msg [String] error message
  # @raise [ArgumentError] if EINVAL was reported
  # @raise [Interrupt] if EINTR was reported
  # @raise [SocketError] if EHOSTUNREACH was reported
  # @raise [SystemCallError] any other reported error (appropriate
  #   SystemCallError subclass, if errno is known)
  def raise_zmq_err(msg = CZMQ::FFI::Errors.strerror,
                    errno: CZMQ::FFI::Errors.errno)

    case errno
    when Errno::EINVAL::Errno       then raise ArgumentError, msg, caller
    when Errno::EINTR::Errno        then raise Interrupt, msg, caller
    when Errno::EHOSTUNREACH::Errno then raise SocketError, msg, caller

    # If the errno is known, the corresponding Errno::* exception is
    # automatically constructed. Otherwise, it'll be a plain SystemCallError.
    # In any case, #errno will return the corresponding errno.
    else raise SystemCallError.new(msg, errno), msg, caller
    end
  end


  # Some class methods related to FFI delegates.
  module ClassMethods
    include Forwardable

    # Delegate specified instance method to the registered FFI delegate.
    # @note It only takes one method name so it's easy to add some
    #   documentation for each delegated method.
    # @param method [Symbol] method to delegate
    # @return [void]
    def ffi_delegate(method)
      def_delegator(:@ffi_delegate, method)
    end


    # Allocates a new instance and attaches the FFI delegate to it. This is
    # useful if you already have an FFI delegate and need to attach it to a
    # fresh high-level object.
    # @return [CZTop::*] the fresh object
    # @note #initialize won't be called on the fresh object. This works around
    #   the fact that #initialize usually assumes that no FFI delegate is
    #   attached yet and will try to do so (and also expect to be called in a
    #   specific way).
    def from_ffi_delegate(ffi_delegate)
      obj = allocate
      obj.attach_ffi_delegate(ffi_delegate)
      obj
    end
  end
end
