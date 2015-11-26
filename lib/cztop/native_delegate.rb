module CZTop::NativeDelegate
  attr_reader :delegate

  def to_ptr
    @delegate.to_ptr
  end

  def delegate=(delegate)
    raise CZTop::InitializationError if delegate.null?
    @delegate = delegate
  end

  module ClassMethods
    def native_delegate(*methods)
      def_delegators(:@delegate, *methods)
    end

    def from_delegate(delegate)
      obj = new
      obj.delegate = delegate
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
