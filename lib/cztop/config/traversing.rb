# Methods used to traverse a {CZTop::Config} tree.
module CZTop::Config::Traversing
  # Calls the given block once for each {Config} item in the tree, starting
  # with self.
  #
  # @yieldparam config [Config] the config item
  # @yieldparam level [Integer] level of the item (self has level 0,
  #   its direct children have level 1)
  # @return [self]
  # @raise [Exception] the block's exception, in case it raises (it won't
  #   call the block any more after that)
  # @raise [Error] if zconfig_execute() returns an error code
  def execute
    exception = nil
    callback = CZMQ::FFI::Zconfig.fct do |zconfig, _arg, level|
      begin
        config = from_ffi_delegate(zconfig)
        yield config, level

        0 # report success to keep zconfig_execute() going
      rescue
        # remember exception, so we can raise it later to the ruby code
        # (it can't be raised now, as we have to report failure to
        # zconfig_execute())
        exception = $!

        -1 # report failure to stop zconfig_execute() immediately
      end
    end
    rc = ffi_delegate.execute(callback, _arg = nil)
    raise exception if exception
    raise Error, "zconfig_execute() returned failure code" if rc.nonzero?
    return self
  end

  # Access to this config item's direct children.
  # @return [SiblingsAccessor]
  def children
    SiblingsAccessor.of_parent(self)
  end

  # Access to this config item's siblings.
  # @note Only the "younger" (later in the ZPL file) config items are
  #   considered.
  # @return [SiblingsAccessor]
  def siblings
    SiblingsAccessor.of_older_sibling(self)
  end

  # Accesses a set of siblings, which can either be all direct children of
  # a config item, or all younger siblings of a config item.
  class SiblingsAccessor
    include Enumerable
    # Used to create a {SiblingsAccessor} for the provided config item's
    # direct children.
    # @param config [Config] the parent config item
    # @return [SiblingsAccessor]
    def self.of_parent(config)
      ptr = config.ffi_delegate.child
      child = ptr.null? ? nil : config.from_ffi_delegate(ptr)
      new(child)
    end
    # Used to create a {SiblingsAccessor} for the provided config item's
    # siblings (not including itself).
    # @param config [Config] ideally the "oldest" sibling config item
    # @return [SiblingsAccessor]
    def self.of_older_sibling(config)
      ptr = config.ffi_delegate.next
      sibling = ptr.null? ? nil : config.from_ffi_delegate(ptr)
      new(sibling)
    end
    def initialize(config)
      @config = config
    end
    # Returns the first sibling/child.
    # @return [Config]
    # @return [nil] if no more siblings/no children
    def first
      @config
    end
    # Yields all further siblings.
    # @yieldparam config [Config]
    def each
      return unless @config
      yield @config
      current = @config.ffi_delegate
      while sibling = current.next
        break if sibling.null?
        yield @config.from_ffi_delegate(sibling)
        current = sibling
      end
    end
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

  # Finds last item at given level (0 = root).
  # @return [Config] the last config item at given level
  # @return [nil] if there's no config item at given level
  def last_at_depth(level)
    ptr = ffi_delegate.at_depth(level)
    return nil if ptr.null?
    from_ffi_delegate(ptr)
  end
end

class CZTop::Config
  include Traversing
end
