module CZTop
  class Config

    # Access this config item's comments.
    # @note Note that comments are discarded when loading a config (either from
    #   a string or file) and thus, only the comments you add during runtime
    #   are accessible.
    # @return [CommentsAccessor]
    def comments
      return CommentsAccessor.new(self)
    end

    # Used to access a {Config}'s comments.
    class CommentsAccessor
      include Enumerable

      # @param config [Config]
      def initialize(config)
        @config = config
      end

      # @return [CZMQ::FFI::Zlist] the zlist of comments for this config item
      def zlist
        @config.ffi_delegate.comments
      end

      # @param new_comment [String]
      # @return [self]
      def <<(new_comment)
        @config.ffi_delegate.set_comment("%s", :string, new_comment)
        return self
      end

      # Deletes all comments for this {Config} item.
      def delete_all
        @config.ffi_delegate.set_comment(nil)
      end

      # Yields all comments for this {Config} item.
      # @yieldparam comment [String]
      def each
        while comment = zlist.next
          break if comment.null?
          yield comment.read_string
        end
      rescue CZMQ::FFI::Zlist::DestroyedError
      end

      # @return [Integer]
      def size
        zlist.size
      rescue CZMQ::FFI::Zlist::DestroyedError
        0
      end
    end
  end
end
