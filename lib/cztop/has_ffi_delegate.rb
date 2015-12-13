require 'forwardable'

module CZTop
  # This is raised when trying to attach an FFI delegate (an instance from one
  # of the classes in the CZMQ::FFI namespace) whose internal pointer has been
  # nullified.
  class InitializationError < ::FFI::NullPointerError; end
end

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
  # @raise [CZTop::InitializationError] if delegate is #null?
  # @return [void]
  def attach_ffi_delegate(ffi_delegate)
    raise CZTop::InitializationError if ffi_delegate.null?
    @ffi_delegate = ffi_delegate
  end

  # Same as the counterpart in {ClassMethods}, but usable from within an
  # instance.
  # @see CZTop::FFIDelegate::ClassMethods#from_ffi_delegate
  # @return [CZTop::*] the new object
  def from_ffi_delegate(ffi_delegate)
    self.class.from_ffi_delegate(ffi_delegate)
  end

  module ClassMethods
    include Forwardable

    # Delegate specified instance method to the registered FFI delegate.
    # @note It only takes one method name so it's easy to add some
    #   documentation for each delegated method.
    # @param method [Symbol] method to delegate
    # @return [void]
    def ffi_delegate(method)
      def_delegators(:@ffi_delegate, method)
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
      return obj
    end
  end
end
