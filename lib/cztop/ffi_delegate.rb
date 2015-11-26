module CZTop::FFIDelegate
  # @return [CZMQ::FFI::*]
  attr_accessor :ffi_delegate

  # @return [FFI::Pointer] FFI delegate's pointer
  def to_ptr
    @ffi_delegate.to_ptr
  end

  # Attaches an FFI delegate to the current (probably new) {CZTop} object.
  # @param ffi_delegate an instance of the corresponding class in the {CZMQ::FFI} namespace
  # @raise [CZTop::InitializationError] if delegate is #null?
  def attach_ffi_delegate(ffi_delegate)
    raise CZTop::InitializationError if ffi_delegate.null?
    self.ffi_delegate = ffi_delegate
  end

  module ClassMethods
    # Delegate specified instance methods to the registered FFI delegates.
    # @param methods [Array<Symbol>] methods to delegate
    def ffi_delegate(*methods)
      def_delegators(:@ffi_delegate, *methods)
    end

    def from_ffi_delegate(ffi_delegate)
      obj = new
      obj.attach_ffi_delegate(ffi_delegate)
      return obj
    end
  end

  def self.included(m)
    m.class_eval do
      extend Forwardable
      extend ClassMethods
    end
  end
end
