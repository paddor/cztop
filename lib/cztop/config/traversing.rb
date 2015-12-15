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
  # @return [ChildrenAccessor]
  def children
    ChildrenAccessor.new(self)
  end

  # Access to this config item's siblings.
  # @note Only the "younger" (later in the ZPL file) config items are
  #   considered.
  # @return [SiblingsAccessor]
  def siblings
    SiblingsAccessor.new(self)
  end

  # Used to give access to a {Config} item's children or siblings.
  # @abstract
  class FamilyAccessor
    include Enumerable

    # @param config [Config] the relative starting point (either parent or
    #   an older sibling)
    def initialize(config)
      @config = config
    end

    # This is supposed to return the first relevant config item.
    # @abstract
    # @return [Config, nil]
    def first; end

    # Yields all direct children/younger siblings. Starts with {#first}, if
    # set.
    # @yieldparam config [Config]
    def each
      current = first()
      return if current.nil?
      yield current
      current_delegate = current.ffi_delegate
      while current_delegate = current_delegate.next
        break if current_delegate.null?
        yield CZTop::Config.from_ffi_delegate(current_delegate)
      end
    end

    def ==(other)
      to_a == other.to_a
    end
  end

  # Accesses the younger siblings of a given {Config} item.
  class SiblingsAccessor < FamilyAccessor
    # Returns the first sibling.
    # @return [Config]
    # @return [nil] if no younger siblings
    def first
      ptr = @config.ffi_delegate.next
      return nil if ptr.null?
      CZTop::Config.from_ffi_delegate(ptr)
    end
  end

  # Accesses the direct children of a given {Config} item.
  class ChildrenAccessor < FamilyAccessor
    def first
      ptr = @config.ffi_delegate.child
      return nil if ptr.null?
      CZTop::Config.from_ffi_delegate(ptr)
    end

    # Adds a new Config item and yields it, so it can be configured in
    # a block.
    # @param name [String] name for new config item
    # @param value [String] value for new config item
    # @yieldparam [Config] the new config item, if block was given
    # @return [Config] the new config item
    def new(name = nil, value = nil)
      config = CZTop::Config.new(name, value, parent: @config)
      yield config if block_given?
      config
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
