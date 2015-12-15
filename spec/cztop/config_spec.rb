require_relative 'spec_helper'

describe CZTop::Config do

  describe "#initialize" do
    context "with a name" do
      let(:name) { "foo" }
      let(:config) { described_class.new name }
      it "sets that name" do
        assert_equal name, config.name
      end
    end
    context "with no name" do
      let(:config) { described_class.new }
      it "creates a config item anyway" do
        assert_kind_of described_class, config
      end
      it "has nil name" do
        assert_nil config.name
      end
    end
    context "with name and value" do
      let(:name) { "foo" }
      let(:value) { "bar" }
      let(:config) { described_class.new name, value }
      it "sets name and value" do
        assert_equal name, config.name
        assert_equal value, config.value
      end
    end
    context "given a parent" do
      let(:parent_name) { "foo" }
      let(:parent_config) { described_class.new parent_name }
      let(:name) { "bar" }
      let(:config) { described_class.new name, parent: parent_config }
      it "appends it to that parent" do
        assert_nil parent_config.children.first
        config
        assert_equal config.to_ptr, parent_config.children.first.to_ptr
      end

      it "removes finalizer from delegate" do # parent will free it
        assert_nil config.ffi_delegate.instance_variable_get(:@finalizer)
      end
    end
    context "with no parent" do
      let(:config) { described_class.new }
      it "doesn't remove finalizer from delegate" do
        refute_nil config.ffi_delegate.instance_variable_get(:@finalizer)
      end
    end
    context "with a block" do
      it "yields self" do
        yielded = nil
        config = described_class.new { |c| yielded = c }
        assert_same config, yielded
      end
    end
  end

  context "given a config" do
    let(:config_contents) do
      <<-EOF
context
    iothreads = 1
    verbose = 1      #   Ask for a trace
main
    type = zqueue    #  ZMQ_DEVICE type
    frontend
        option
            hwm = 1000
            swap = 25000000     #  25MB
        bind = 'inproc:@@//@@addr1'
        bind = 'ipc:@@//@@addr2'
    backend
        bind = inproc:@@//@@addr3
      EOF
    end

    let(:config) { described_class.from_string(config_contents) }

    describe "#==" do
      Given(:this_name) { "foo" }
      Given(:this_value) { "bar" }
      Given(:this) { described_class.new(this_name, this_value) }

      context "with equal config" do
        Given(:that) { described_class.new(this_name, this_value) }
        Then { this == that }
        And { that == this }
      end
      context "with different config" do
        Given(:that_name) { "quu" }
        Given(:that_value) { "quux" }

        context "with different name" do
          Given(:that) { described_class.new(that_name, this_value) }
          Then { this != that }
          And  { that != this }
        end

        context "with different value" do
          Given(:that) { described_class.new(this_name, that_value) }
          Then { this != that }
          And  { that != this }
        end
      end
    end

    describe "#tree_equal?" do
      context "given equal config tree" do
        Given(:this) { config.locate("main/frontend") }
        Given(:other) { described_class.from_string(config_contents) }
        Given(:that) { other.locate("main/frontend") }
        When do
          # mangle an independent side-tree a bit
          backend = config.locate("main/backend")
          backend.name = "foobar"
          backend.children.new("foo", "bar")
        end
        Then { this.tree_equal? that }
        And { that.tree_equal? this }
      end
      context "given different config tree" do
        let(:other_config) { described_class.new("foo") }
        Then { !config.tree_equal?(other_config) }
        And  { !other_config.tree_equal?(config) }
      end
    end

    describe "#name" do
      it "returns name" do
        assert_equal "root", config.name
        assert_equal "context", config.children.first.name
      end
    end

    describe "#name=" do
      let(:new_name) { "foo" }
      it "sets name" do
        config.name = new_name
        assert_equal new_name, config.name
      end
    end

    describe "#value" do
      let(:config_contents) do
        <<-EOF
a = 1
b = ""
c
    d = "foo"
    f = bar
    g
    h # no value either
        EOF
      end
      context "with no value" do
        let(:item) { config.locate("/c/g") }
        it "returns the empty string" do
          assert_empty item.value
        end
      end

      context "with value" do
        let(:paths_values) do
          { "a" => "1",
            "b" => "",
            "c" => "",
            "c/d" => "foo",
            "c/f" => "bar",
            "c/g" => "",
            "c/h" => "" }
        end
        it "reads value" do
          paths_values.each do |path,expected|
            assert_equal expected, config.locate(path).value
          end
        end
      end
    end

    describe "#value=" do
      let(:item) { config.locate("main/frontend/option/hwm") }
      before(:each) do
        item.value = new_value
      end
      context "given safe string" do
        let(:new_value) { "foo bar" }

        it "sets value" do
          assert_equal new_value, item.value
        end
      end

      context "given integer" do
        let(:new_value) { 555 }

        it "sets value" do
          assert_equal new_value.to_s, item.value
        end
      end

      context "given unsafe, user-supplied value" do
        let(:new_value) { "%s" }

        it "sets value" do
          assert_equal new_value, item.value
        end
      end
    end

    describe "#[]=" do
      context "given a path and value" do
        let(:path) { "main/type" }
        let(:new_value) { "foobar" }
        it "changes the item's value" do
          refute_equal new_value, config[path]
          config[path] = new_value
          assert_equal new_value, config[path]
        end
        it "has alias #put" do
          config.put(path, new_value)
          assert_equal new_value, config[path]
        end
      end
    end

    describe "#[]" do
      context "given existing path" do
        context "with value set" do
          let(:path) { "main/type" }
          it "returns correct value" do
            assert_equal "zqueue", config.get(path)
          end

          it "has alias #get" do
            assert_equal config[path], config.get(path)
          end
        end
        context "with no value set" do
          let(:path) { "main/frontend" }
          it "returns the empty string" do
            assert_empty config[path]
          end

          context "given default value" do
            let(:default) { "my default value" }
            it "returns empty string" do
              assert_empty config[path, default]
            end
          end
        end
      end

      context "given non-existent path" do
        let(:path) { "main/foobar" }
        it "returns the empty string" do
          assert_empty config[path]
        end

        context "given default value" do
          let(:default) { "my default value" }
          it "returns default value" do
            assert_equal default, config[path, default]
          end
        end
      end
    end
  end
end
