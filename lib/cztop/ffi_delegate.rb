module CZTop::FFIDelegate
  # @return [CZMQ::FFI::*]
  attr_accessor :ffi_delegate

  # @return [FFI::Pointer] FFI delegate's pointer
  def to_ptr
    @ffi_delegate.to_ptr
  end

  # Attaches an FFI delegate to the current (probably new) {CZTop} object.
  # @param ffi_delegate an instance of the corresponding class in the
  #   {CZMQ::FFI} namespace
  # @raise [CZTop::InitializationError] if delegate is #null?
  # @return [void]
  def attach_ffi_delegate(ffi_delegate)
    raise CZTop::InitializationError if ffi_delegate.null?
    self.ffi_delegate = ffi_delegate
  end

  # Same as the counterpart in {ClassMethods}, but usable from within an
  # instance.
  # @see CZTop::FFIDelegate::ClassMethods#from_ffi_delegate
  # @return [CZTop::*] the new object
  def from_ffi_delegate(*args)
    self.class.from_ffi_delegate(*args)
  end

  module ClassMethods
    # Delegate specified instance methods to the registered FFI delegates.
    # @param methods [Array<Symbol>] methods to delegate
    # @return [void]
    def ffi_delegate(*methods)
      def_delegators(:@ffi_delegate, *methods)
    end

    # Allocates a new instance and attaches the FFI delegate to it.
    # @return [CZTop::*] the new object
    # @note #initialize won't be called on the new object
    def from_ffi_delegate(ffi_delegate)
      obj = allocate
      obj.attach_ffi_delegate(ffi_delegate)
      return obj
    end
  end

  # Ruby callback. This will extend m with Forwardable and {ClassMethods}.
  # @param m [Module] the module/class which included this module
  # @return [void]
  def self.included(m)
    m.class_eval do
      extend Forwardable
      extend ClassMethods
    end
  end
end
