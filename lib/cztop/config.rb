module CZTop

  # Represents a {CZMQ::FFI::Zconfig} item.
  # @see http://rfc.zeromq.org/spec:4/ZPL
  class Config
    # @!parse extend CZTop::HasFFIDelegate::ClassMethods


    include HasFFIDelegate

    class Error < RuntimeError; end

    # Initializes a new {Config} item. Takes an optional block to initialize
    # the item further.
    # @param name [String] config item name
    # @param name [Config] parent
    # @yieldparam config [self]
    # @note If parent is given, the native child will be destroyed when the
    #   native parent is destroyed (and not when the child's corresponding
    #   {Config} object is garbage collected).
    def initialize(name = nil, parent = nil)
      parent = parent.ffi_delegate if parent.is_a?(Config)
      delegate = ::CZMQ::FFI::Zconfig.new(name, parent)
      attach_ffi_delegate(delegate)

      # NOTE: this delegate must not be freed automatically, because the
      # parent will free it.
      delegate.__undef_finalizer

      yield self if block_given?
    end

    # @!group ZPL attributes

    # @return [String] name of the config item
    def name
      ptr = ffi_delegate.name
      return nil if ptr.null? # NOTE: for unnamed elements
      ptr.read_string
    end
    # @param new_name [String, #to_s]
    # @return [new_name]
    def name=(new_name)
      ffi_delegate.set_name(new_name.to_s)
    end

    # Get the value of the config item.
    # @return [String]
    # @note This returns an empty string if the value is unset.
    def value
      ptr = ffi_delegate.value
      return "" if ptr.null? # NOTE: for root elements
      ptr.read_string
    end

    # Set or update the value of the config item.
    # @param new_value [String, #to_s]
    # @return [new_value]
    def value=(new_value)
      ffi_delegate.set_value("%s", :string, new_value.to_s)
    end

    # Update the value of a config item by path.
    # @param path [String, #to_s] path to config item
    # @param value [String, #to_s] path to config item
    # @return [value]
    def []=(path, value)
      ffi_delegate.put(path.to_s, value.to_s)
    end
    alias_method :put, :[]=

    # Get the value of the current config item.
    # @param path [String, #to_s] path to config item
    # @param default [String, #to_s] default value to return if config item
    #   doesn't exist
    # @return [String]
    # @return [default] if config item doesn't exist
    # @note The default value is not returned when the config item exists but
    #   just doesn't have a value. In that case, it'll return the empty
    #   string.
    def [](path, default = "")
      ptr = ffi_delegate.get(path, default)
      return nil if ptr.null?
      ptr.read_string
    end
    alias_method :get, :[]

    # @return [Boolean]
    def ==(other)
      name == other.name &&
      value == other.value &&
      children.first == other.children.first &&
      self.siblings.first == other.siblings.first
    end
  end
end
