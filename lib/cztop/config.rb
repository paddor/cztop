module CZTop

  # Represents a {CZMQ::FFI::Zconfig} item.
  class Config
    include FFIDelegate

    def initialize(name, parent)
    end

    def name
      # TODO
    end
    def name=(new_name)
      # TODO
    end

    def value
      # TODO
    end
    def value=(new_value)
      # TODO
    end

    def put(path, value)
      # TODO
    end
    alias_method :[]=, :put

    def get(path, default=nil)
      # TODO
    end
    alias_method :[], :get


    def children
      # TODO
    end

    def siblings
      # TODO
    end

    def locate(path)
      # TODO
    end

    def last_at_depth(level)
      # TODO
    end

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

    def self.load(path)
      from_ffi_delegate(CZMQ::FFI::Zconfig.load(path.to_s))
    end

    def save(filename)
      # TODO
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
      ptr = Zconfig.load_str(string)
      from_ptr(ptr)
    end

    # @return [String]
    def filename
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

    def self.from_string(string)
      # TODO
    end

    # Used to access a {Config}'s comments.
    class Comments
      include Enumerable

      # @param message [Message]
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
