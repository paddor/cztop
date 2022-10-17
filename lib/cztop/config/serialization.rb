# frozen_string_literal: true

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


  # Some class methods for {Config} related to serialization.
  module ClassMethods
    # Loads a {Config} tree from a string.
    # @param string [String] the tree
    # @return [Config]
    def from_string(string)
      from_ffi_delegate CZMQ::FFI::Zconfig.str_load(string)
    end


    # Loads a {Config} tree from a file.
    # @param path [String, Pathname, #to_s] the path to the ZPL config file
    # @raise [SystemCallError] if this fails
    # @return [Config]
    def load(path)
      ptr = CZMQ::FFI::Zconfig.load(path.to_s)
      return from_ffi_delegate(ptr) unless ptr.null?

      CZTop::HasFFIDelegate.raise_zmq_err(
        format('error while reading the file %p', path.to_s)
      )
    end


    # Loads a {Config} tree from a marshalled string.
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
  # @raise [SystemCallError] if this fails
  def save(path)
    rc = ffi_delegate.save(path.to_s)
    return if rc.zero?

    raise_zmq_err(format('error while saving to the file %s', path))
  end


  # Reload config tree from same file that it was previously loaded from.
  # @raise [TypeError] if this is an in-memory config
  # @raise [SystemCallError] if this fails (no existing data will be
  #   changed)
  # @return [void]
  def reload
    # NOTE: can't use Zconfig.reload, as we won't get the self pointer that
    # gets reassigned by zconfig_reload(). We can just use Zconfig.load and
    # swap out the FFI delegate.
    filename = filename() or
      raise TypeError, "can't reload in-memory config"
    ptr      = CZMQ::FFI::Zconfig.load(filename)
    return attach_ffi_delegate(ptr) unless ptr.null?

    raise_zmq_err(format('error while reloading from the file %p', filename))
  end


  # Serialize (marshal) this Config and all its children.
  #
  # @note This method is automatically used by Marshal.dump.
  # @return [String] marshalled {Config}
  def _dump(_level)
    to_s
  end
end


class CZTop::Config
  include Serialization
  extend Serialization::ClassMethods
end
