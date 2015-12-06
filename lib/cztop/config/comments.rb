module CZTop
  class Config
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
