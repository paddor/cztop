module CZTop
  class Config
    def initialize(name, parent)
    end

    def name
    end
    def name=(new_name)
    end

    def value
    end
    def value=(new_value)
    end

    def put(path, value)
    end
    alias_method :[]=, :put

    def get(path, default=nil)
    end
    alias_method :[], :get


    def children
    end

    def siblings
    end

    def locate(path)
    end

    def last_at_depth(level)
    end

    # Config::Comments
    def comments
      zlist_ptr = deletage.comments
      return Comments.new_from_ptr(zlist_ptr)
    end

    def self.load(filename)
    end
    def save(filename)
    end

    # Serialize (marshal) this Config and all its children.
    #
    # @note This method is automatically used by {Marshal.dump}.
    # @return [String]
    def _dump(level)
    end

    # Load a Config object from a marshalled string.
    #
    # @note This method is automatically used by {Marshal.load}.
    # @return [Config]
    def self._load(string)
      ptr = Zconfig.load_str(string)
      from_ptr(ptr)
    end

    def filename
    end

    def reload
    end

    def self.from_string(string)
    end

    class Comments
      include Enumerable
      def <<(new_comment)
      end
      def each
      end
    end
  end
end
