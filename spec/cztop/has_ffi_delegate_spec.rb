require_relative '../spec_helper'

describe CZTop::HasFFIDelegate do
  let(:delegate_class) do
    Class.new do
      def initialize(ptr) @ptr = ptr end
      def to_ptr() @ptr end
      def null?() @ptr.nil?  end
      def foo() :foo end
    end
  end

  let(:ptr) { "some pointer" }
  let(:delegate) { delegate_class.new(ptr) }
  let(:delegator_class) do
    Class.new do
      include CZTop::HasFFIDelegate
      extend CZTop::HasFFIDelegate::ClassMethods
    end
  end
  let(:delegator) { delegator_class.new }

  describe ".ffi_delegate" do
    let(:method) { :m1 }
    it "defines delegator method" do
      expect(delegator_class).to receive(:def_delegator).
        with(:@ffi_delegate, method)
      delegator_class.ffi_delegate(method)
    end

    it "doesn't take multiple method names" do # for better documentation
      assert_raises(ArgumentError) do
        delegator_class.ffi_delegate(:foo, :bar)
      end
    end
  end

  describe "#ffi_delegate" do
    context "with no delegate attached" do
      it "returns nil" do
        assert_nil delegator.ffi_delegate
      end
    end
    context "with delegate attached" do
      before(:each) { delegator.attach_ffi_delegate(delegate) }
      it "returns delegate" do
        assert_same delegator.ffi_delegate, delegate
      end
    end
  end

  describe "#to_ptr" do
    before(:each) { delegator.attach_ffi_delegate(delegate) }
    it "returns pointer" do
      assert_same ptr, delegator.to_ptr
    end
    it "delegates" do
      expect(delegate).to receive(:to_ptr)
      delegator.to_ptr
    end
  end

  describe "#attach_ffi_delegate" do
    context "with valid delegate" do
      it "attaches delegate" do
        delegator.attach_ffi_delegate(delegate)
        assert_same delegate, delegator.ffi_delegate
      end
    end
    context "with nullified delegate" do
      let(:ptr) { nil } # represents nullpointer
      it "raises" do
        assert_raises(SystemCallError) do
          delegator.attach_ffi_delegate(delegate)
        end
      end
    end
  end

  describe "#from_ffi_delegate" do
    let(:arg) { "foo" }
    it "delegates to class method equivalent" do
      expect(delegator_class).to \
        receive(:from_ffi_delegate).with(arg)
      delegator.from_ffi_delegate(arg)
    end
  end

  describe ".from_ffi_delegate" do
    let(:obj) { delegator_class.from_ffi_delegate(delegate) }

    it "creates a fresh object" do
      assert_instance_of delegator_class, obj
    end
    it "attaches delegate" do
      assert_same delegate, obj.ffi_delegate
    end

    context "with constructor that shouldn't be called in this case" do
      # A typical constructor would be:
      #
      #   def initialize(content = "")
      #     delegate = LowLevelClass.new_from_content(content)
      #     attach_ffi_delegate(delegate)
      #   end
      #
      # And this kind of constructor must not be called in this case.
      before(:each) do
        delegator_class.class_exec { define_method(:initialize) { raise } }
      end

      it "won't call the constructor" do
        assert_same delegate, obj.ffi_delegate
      end
    end
  end
end
