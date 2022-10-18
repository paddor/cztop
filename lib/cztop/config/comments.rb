# frozen_string_literal: true

module CZTop
  class Config

    # Access this config item's comments.
    # @note Note that comments are discarded when loading a config (either from
    #   a string or file) and thus, only the comments you add during runtime
    #   are accessible.
    # @return [CommentsAccessor]
    def comments
      CommentsAccessor.new(self)
    end


    # Used to access a {Config}'s comments.
    class CommentsAccessor

      include Enumerable

      # @param config [Config]
      def initialize(config)
        @config = config
      end


      # Adds a new comment.
      # @param new_comment [String]
      # @return [self]
      def <<(new_comment)
        @config.ffi_delegate.set_comment('%s', :string, new_comment)
        self
      end


      # Deletes all comments for this {Config} item.
      # @return [void]
      def delete_all
        @config.ffi_delegate.set_comment(nil)
      end


      # Yields all comments for this {Config} item.
      # @yieldparam comment [String]
      # @return [void]
      def each
        while comment = _zlist.next
          break if comment.null?

          yield comment.read_string
        end
      rescue CZMQ::FFI::Zlist::DestroyedError
        # there are no comments
        nil
      end


      # Returns the number of comments for this {Config} item.
      # @return [Integer] number of comments
      def size
        _zlist.size
      rescue CZMQ::FFI::Zlist::DestroyedError
        0
      end

      private

      # Returns the Zlist to the list of comments for this config item.
      # @return [CZMQ::FFI::Zlist] the zlist of comments for this config item
      def _zlist
        @config.ffi_delegate.comments
      end

    end

  end
end
