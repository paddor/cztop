# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::HasFFIDelegate do
  let(:delegate_class) do
    Class.new do
      def initialize(ptr)
        @ptr = ptr
      end


      def to_ptr
        @ptr
      end


      def null?
        @ptr.nil?
      end


      def foo
        :foo
      end
    end
  end

  let(:ptr)      { 'some pointer' }
  let(:delegate) { delegate_class.new(ptr) }
  let(:delegator_class) do
    Class.new do
      include CZTop::HasFFIDelegate
      extend CZTop::HasFFIDelegate::ClassMethods
    end
  end
  let(:delegator) { delegator_class.new }


  describe '.ffi_delegate' do
    let(:method_name) { :m1 }

    it 'defines delegator method' do
      called_with = nil
      delegator_class.stub(:def_delegator, ->(*args) { called_with = args }) do
        delegator_class.ffi_delegate(method_name)
      end
      assert_equal [:@ffi_delegate, method_name], called_with
    end

    it "doesn't take multiple method names" do # for better documentation
      assert_raises(ArgumentError) do
        delegator_class.ffi_delegate(:foo, :bar)
      end
    end
  end


  describe '#ffi_delegate' do
    describe 'with no delegate attached' do
      it 'returns nil' do
        assert_nil delegator.ffi_delegate
      end
    end


    describe 'with delegate attached' do
      before { delegator.attach_ffi_delegate(delegate) }

      it 'returns delegate' do
        assert_same delegator.ffi_delegate, delegate
      end
    end
  end


  describe '#to_ptr' do
    before { delegator.attach_ffi_delegate(delegate) }

    it 'returns pointer' do
      assert_same ptr, delegator.to_ptr
    end

    it 'delegates' do
      called = false
      delegate.stub(:to_ptr, -> { called = true; ptr }) do
        delegator.to_ptr
      end
      assert called
    end
  end


  describe '#attach_ffi_delegate' do
    describe 'with valid delegate' do
      it 'attaches delegate' do
        delegator.attach_ffi_delegate(delegate)
        assert_same delegate, delegator.ffi_delegate
      end
    end


    describe 'with nullified delegate' do
      let(:ptr) { nil } # represents nullpointer

      it 'raises' do
        CZMQ::FFI::Errors.stub(:errno, Errno::EINVAL::Errno) do
          assert_raises(ArgumentError) do
            delegator.attach_ffi_delegate(delegate)
          end
        end
      end
    end
  end


  describe '#from_ffi_delegate' do
    let(:arg) { 'foo' }

    it 'delegates to class method equivalent' do
      called_with = nil
      delegator_class.stub(:from_ffi_delegate, ->(a) { called_with = a }) do
        delegator.from_ffi_delegate(arg)
      end
      assert_equal arg, called_with
    end
  end


  describe '.from_ffi_delegate' do
    let(:obj) { delegator_class.from_ffi_delegate(delegate) }

    it 'creates a fresh object' do
      assert_instance_of delegator_class, obj
    end

    it 'attaches delegate' do
      assert_same delegate, obj.ffi_delegate
    end


    describe "with constructor that shouldn't be called in this case" do
      # A typical constructor would be:
      #
      #   def initialize(content = "")
      #     delegate = LowLevelClass.new_from_content(content)
      #     attach_ffi_delegate(delegate)
      #   end
      #
      # And this kind of constructor must not be called in this case.
      before do
        delegator_class.class_exec { define_method(:initialize) { raise } }
      end

      it "won't call the constructor" do
        assert_same delegate, obj.ffi_delegate
      end
    end
  end
end
