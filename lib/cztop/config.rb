module CZTop

  # Represents a {CZMQ::FFI::Zconfig} item.
  # @see http://rfc.zeromq.org/spec:4/ZPL
  class Config
    # @!parse extend CZTop::FFIDelegate::ClassMethods


    include FFIDelegate
    include Enumerable

    class Error < RuntimeError; end

    def initialize(name, parent)
      # TODO
    end

    # @!group ZPL attributes

    # @return [String] name of the config item
    def name
      ffi_delegate.name.read_string
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
      ffi_delegate.value.read_string
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

    # @!endgroup
    # @!group Traversing

    # Calls the given block once for each {Config} item in the tree, starting
    # with self, passing that element as a parameter.
    #
    # An Enumerator is returned if no block is given.
    #
    # @overload each(&block)
    #   @yieldparam config [Config] the config item
    #   @yieldparam level [Integer] level of the item (self has level 0,
    #     its direct children have level 1)
    #   @note The second parameter +level+ is only yielded if the given block
    #     expects exactly 2 parameters. This is to ensure that Enumerable#to_a
    #     works as expected, returning an array of {Config} items.
    #   @return [self]
    #   @raise [Exception] the block's exception, in case it raises (it won't
    #     call the block any more after that)
    # @overload each()
    #   @return [Enumerator]
    # @raise [Error] if zconfig_execute() returns an error code
    def each
      return to_a.each unless block_given?

      exception = nil
      level_wanted = Proc.new.arity == 2
      callback = CZMQ::FFI::Zconfig.fct do |zconfig, _arg, level|
        begin
          config = from_ffi_delegate(zconfig)

          if level_wanted
            yield config, level
          else
            # make Enumerable#to_a work as expected
            yield config
          end

          0 # report success to keep zconfig_execute() going
        rescue
          # remember exception, so we can raise it later to the ruby code
          # (it can't be raised now, as we have to report failure to
          # zconfig_execute())
          exception = $!

          -1 # report failure to stop zconfig_execute() immediately
        end
      end
      ret = ffi_delegate.execute(callback, arg = nil)
      raise exception if exception
      raise Error, "zconfig_execute() returned failure code" if ret.nonzero?
      return self
    end

    # @return [Array<Config>]
    # @see #each
    def children
      to_a[1..-1]
    end

    def siblings
      # TODO
    end

    # Finds a config item along a path, relative to the current item.
    # @param path [String] path (leading slash is optional and will be
    #   ignored)
    # @return [Config] the found config item
    # @return [nil] if there's no config item under this path
    def locate(path)
      ptr = ffi_delegate.locate(path)
      return nil if ptr.null?
      from_ffi_delegate(ptr)
    end

    def last_at_depth(level)
      # TODO
    end

    # @!endgroup
    # @!group Comments

    # Config::Comments
    def comments
      zlist_ptr = delegate.comments
      return Comments.new_from_ptr(zlist_ptr)
    end

    # @param new_comment [String]
    def add_comment(new_comment)
      new_comment_ptr = ::FFI::MemoryPointer.from_string(new_comment)
      delegate.set_comment(new_comment_ptr)
    end

    # Deletes all comments for this {Config} item.
    def delete_comments
      delegate.set_comment(nil)
    end

    # @!endgroup
    # @!group Saving and Loading

    # @return [String]
    ffi_delegate :filename

    # Loads a {Config} tree from a string.
    # @param string [String] the tree
    # @return [Config]
    def self.from_string(string)
      from_ffi_delegate CZMQ::FFI::Zconfig.str_load(string)
    end
    # Loads a Config tree from a file.
    # @param path [String, Pathname, #to_s] the path to the ZPL config file
    # @return [Config]
    def self.load(path)
      from_ffi_delegate(CZMQ::FFI::Zconfig.load(path.to_s))
    rescue CZTop::InitializationError
      raise Error, "error while reading file: %p" % path.to_s
    end

    # Saves the Config tree to a file.
    # @param path [String, Pathname, #to_s] the path to the ZPL config file
    def save(path)
      # TODO
    end

    class ReloadError < RuntimeError; end

    # Reload config tree from same file that it was previously loaded from.
    # @raise [ReloadError] if there's an error (no existing data will be
    #   changed)
    def reload
      ret = delegate.reload
      raise ReloadError if ret == -1
    end

    # Serialize (marshal) this Config and all its children.
    #
    # @note This method is automatically used by Marshal.dump.
    # @return [String]
    def _dump(level)
      # TODO
    end

    # Load a Config object from a marshalled string.
    #
    # @note This method is automatically used by Marshal.load.
    # @return [Config]
    def self._load(string)
      ptr = CZMQ::FFI::Zconfig.str_load(string)
      from_ptr(ptr)
    end

    # @!endgroup

    # Used to access a {Config}'s comments.
    class Comments
      include Enumerable

      # @param config [Config]
      def initialize(config)
        @config = config
      end

      # @param new_comment [String]
      def <<(new_comment)
        @config.add_comment(new_comment)
      end

      def delete_all
        @message.delete_comments
      end

      def each
        # use Zconfig.
      # TODO
      end
    end
  end
end
