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
