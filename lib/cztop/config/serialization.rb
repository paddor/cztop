# Methods used around serialization of {CZTop::Config} items.
module CZTop::Config::Serialization
  # Serialize to a string in the ZPL format.
  # @return [String]
  def to_s
    ffi_delegate.str_save.read_string
  end

  # Returns the path/filename of the file this {Config} tree was loaded from.
  # @return [String]
  def filename
    ffi_delegate.filename
  end

  module ClassMethods
    # Loads a {Config} tree from a string.
    # @param string [String] the tree
    # @return [Config]
    def from_string(string)
      from_ffi_delegate CZMQ::FFI::Zconfig.str_load(string)
    end
    # Loads a Config tree from a file.
    # @param path [String, Pathname, #to_s] the path to the ZPL config file
    # @raise [CZTop::Config::Error] if this fails
    # @return [Config]
    def load(path)
      from_ffi_delegate(CZMQ::FFI::Zconfig.load(path.to_s))
    rescue CZTop::InitializationError
      raise CZTop::Config::Error, "error while reading the file %p" % path.to_s
    end

    # Load a Config object from a marshalled string.
    #
    # @note This method is automatically used by Marshal.load.
    # @param string [String] marshalled {Config}
    # @return [Config]
    def _load(string)
      from_string(string)
    end
  end

  # Saves the Config tree to a file.
  # @param path [String, Pathname, #to_s] the path to the ZPL config file
  # @return [void]
  # @raise [CZTop::Config::Error] if this fails
  def save(path)
    rc = ffi_delegate.save(path.to_s)
    raise CZTop::Config::Error, "error while saving to the file %s" % path.to_s if rc == -1
  end

  # Reload config tree from same file that it was previously loaded from.
  # @raise [CZTop::Config::Error] if this fails (no existing data will be
  #   changed)
  # @return [void]
  def reload
    rc = ::CZMQ::FFI::Zconfig.reload(ffi_delegate)
    raise CZTop::Config::Error, "error while reloading from the file %p" % filename if rc == -1
  end

  # Serialize (marshal) this Config and all its children.
  #
  # @note This method is automatically used by Marshal.dump.
  # @return [String] marshalled {Config}
  def _dump(level)
    to_s
  end
end

class CZTop::Config
  include Serialization
  extend Serialization::ClassMethods
end
