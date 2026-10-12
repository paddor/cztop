# frozen_string_literal: true

require_relative '../test_helper'

class CZTopFFITest < Minitest::Spec
  # Evaluate only library loading, before any functions are attached.
  LOADER = File.read(File.expand_path('../../lib/cztop/ffi.rb', __dir__))
    .split('    attach_function', 2).first + "\n  end\nend\n"

  def load_libraries
    namespace = Module.new
    namespace.module_eval(LOADER)
    namespace.const_get(:CZMQ)::FFI.ffi_libraries
  end

  def loaded_library
    CZMQ::FFI.ffi_libraries.first
  end

  it 'prefers runtime sonames for both libraries' do
    attempts = []
    ::FFI::DynamicLibrary.stub(:open, ->(name, *) { attempts << name; loaded_library }) do
      assert_equal [loaded_library, loaded_library], load_libraries
    end
    assert_equal ['libzmq.so.5', 'libczmq.so.4'], attempts
  end

  it 'falls back when versioned libraries cannot be loaded' do
    attempts = []
    ::FFI::DynamicLibrary.stub(:open, ->(name, *) {
      attempts << name
      raise LoadError, 'missing soname' if name.include?('.so.5') || name.include?('.so.4')
      loaded_library
    }) do
      assert_equal [loaded_library, loaded_library], load_libraries
    end
    assert_includes attempts, 'libzmq'
    assert_includes attempts, 'libczmq'
  end

  it 'raises LoadError when a required library has no working candidate' do
    ::FFI::DynamicLibrary.stub(:open, ->(*) { raise LoadError, 'missing library' }) do
      assert_raises(LoadError) { load_libraries }
    end
  end

  it 'requires CZMQ even when ZMQ loads successfully' do
    ::FFI::DynamicLibrary.stub(:open, ->(name, *) {
      raise LoadError, 'missing CZMQ' if name.include?('czmq')
      loaded_library
    }) do
      assert_raises(LoadError) { load_libraries }
    end
  end

  it 'destroys a message retained by CZMQ after a failed send' do
    message = CZMQ::FFI::Zmsg.new
    message.add_buffer('hello')
    socket = CZTop::Socket::PUSH.new
    destroyed = false
    destroy = CZMQ::FFI.method(:zmsg_destroy)
    CZMQ::FFI.stub(:zmsg_send, -1) do
      CZMQ::FFI::Errors.stub(:errno, Errno::EINVAL::Errno) do
        CZMQ::FFI.stub(:zmsg_destroy, ->(ref) {
          destroyed = true
          destroy.call(ref)
        }) do
          assert_raises(ArgumentError) { CZMQ::FFI::Zmsg.send(message, socket) }
        end
      end
    end
    assert destroyed
    assert message.null?
  ensure
    socket&.close
  end

  it 'keeps message ownership if the destination is already closed' do
    message = CZMQ::FFI::Zmsg.new
    socket = CZTop::Socket::PUSH.new
    socket.close
    assert_raises(CZMQ::FFI::DestroyedError) { CZMQ::FFI::Zmsg.send(message, socket) }
    refute message.null?
  end
end

class CZTopFFIZsockTest < Minitest::Spec
  def socket_with_finalizer(factory)
    finalizer = nil
    register = ObjectSpace.method(:define_finalizer)
    socket = ObjectSpace.stub(:define_finalizer, ->(object, callback) {
      finalizer = callback
      register.call(object, callback)
    }) do
      case factory
      when :new then CZMQ::FFI::Zsock.new(CZTop::Socket::Types::PAIR)
      when :new_pair then CZMQ::FFI::Zsock.new_pair(nil)
      end
    end
    [socket, finalizer]
  end

  it 'removes the finalizer before native destruction' do
    socket = CZMQ::FFI::Zsock.new(CZTop::Socket::Types::PAIR)
    events = []
    unregister = ObjectSpace.method(:undefine_finalizer)
    destroy = CZMQ::FFI.method(:zsock_destroy)
    ObjectSpace.stub(:undefine_finalizer, ->(object) {
      events << :unregister
      unregister.call(object)
    }) do
      CZMQ::FFI.stub(:zsock_destroy, ->(ref) {
        events << :destroy
        destroy.call(ref)
      }) { socket.destroy }
    end
    assert_equal [:unregister, :destroy], events
  ensure
    socket&.destroy
  end

  it 'leaves a pending finalizer with a null pointer after native destruction' do
    [:new, :new_pair].each do |factory|
      socket, finalizer = socket_with_finalizer(factory)
      pointers = []
      destroy = CZMQ::FFI.method(:zsock_destroy)
      CZMQ::FFI.stub(:zsock_destroy, ->(ref) {
        pointers << ref.read_pointer
        # Avoid a native double free if the finalizer still holds a stale pointer.
        destroy.call(ref) if pointers.length == 1 || ref.read_pointer.null?
      }) do
        socket.destroy
        finalizer.call(socket.object_id)
      end
      assert_equal 2, pointers.length
      refute pointers.first.null?
      assert pointers.last.null?, "#{factory} finalizer retains a destroyed socket"
    ensure
      socket&.destroy
    end
  end

  it 'rejects use and repeated destruction during native destruction' do
    socket = CZMQ::FFI::Zsock.new(CZTop::Socket::Types::PAIR)
    calls = 0
    closed = false
    error = nil
    destroy = CZMQ::FFI.method(:zsock_destroy)
    CZMQ::FFI.stub(:zsock_destroy, ->(ref) {
      calls += 1
      if calls == 1
        closed = socket.null?
        begin
          socket.to_ptr
        rescue CZMQ::FFI::DestroyedError => e
          error = e
        end
        socket.destroy
        destroy.call(ref)
      end
    }) { socket.destroy }
    assert_equal 1, calls
    assert closed
    assert_instance_of CZMQ::FFI::DestroyedError, error
  ensure
    socket&.destroy
  end
end
