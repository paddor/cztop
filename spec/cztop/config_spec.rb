require_relative 'spec_helper'
require 'tempfile'

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
    context "given a parent" do
      let(:parent_name) { "foo" }
      let(:parent_config) { described_class.new parent_name }
      let(:name) { "bar" }
      let(:config) { described_class.new name, parent_config }
      it "appends it to that parent" do
        assert_nil parent_config.first_child
        config
        assert_equal config.to_ptr, parent_config.first_child.to_ptr
      end

      it "removes finalizer from delegate" do # parent will free it
        refute_operator config.ffi_delegate, :__finalizer_defined?
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

    describe ".from_string" do
      let(:loaded_config) { described_class.from_string(config_contents) }
      context "given a string containing config tree" do
        it "returns a config" do
          assert_kind_of described_class, loaded_config
        end
      end
    end

    describe "#to_s" do
      it "serializes the config tree to a string" do
        assert_kind_of String, config.to_s
      end
      it "serializes correctly" do
        assert_equal config, described_class.from_string(config.to_s)
      end

      context "with only root element" do
        context "with no name" do
          let(:config) { described_class.new }
          it "serializes to empty string" do
            assert_equal "", config.to_s
          end
        end
        context "with name and value set" do
          let(:config) do
            c = described_class.new("foo")
            c.value = "bar"
            c
          end
          # NOTE: doesn't make a lot of sense to me
          it "serializes to empty string" do
            assert_equal "", config.to_s
          end
        end
      end
      context "with root as parent" do
        let(:root) { described_class.new }
        context "with no name" do
          let(:config) { described_class.new nil, root }
          it "serializes to the empty string" do
            assert_equal "", config.to_s
          end
          it "even root serializes to the empty string" do
            assert_equal "", root.to_s
          end
        end
        context "with just a name" do
          let(:name) { "foo" }
          let(:config) { described_class.new(name, root) }
          it "serializes to just the name" do
            assert_equal "", config.to_s
            assert_equal "#{name}\n", root.to_s
          end
        end
        context "with a name and a vaue" do
          let(:name) { "foo" }
          let(:value) { "bar" }
          let(:config) do
            c = described_class.new(name, root)
            c.value = value
            c
          end
          it "serializes to the full config item" do
            assert_equal "", config.to_s
            assert_equal "#{name} = \"#{value}\"\n", root.to_s
          end
        end
      end
    end

    describe "#==" do
      context "given equal config" do
        it "returns true" do
          assert_equal config, config
        end
      end
      context "given different config" do
        let(:other_config) do described_class.new("foo") end
        it "returns false" do
          refute_equal config, other_config
        end
      end
    end

    describe ".load" do
      context "given config file" do
        let(:file) do
          file = Tempfile.new("zconfig_test")
          file.write(config_contents)
          file.rewind
          return file
        end
        let(:filename) { file.path }
        let(:loaded_config) { described_class.load(filename) }
        it "loads the file" do
          assert_kind_of described_class, loaded_config
          assert_equal filename, loaded_config.filename
        end
      end

      context "given no config file" do
        let(:nonexistent_filename) { "/foo/bar.zpl" }
        it "raises CZTop::Config::Error" do
          assert_raises(CZTop::Config::Error) do
            described_class.load(nonexistent_filename)
          end
        end
      end
    end


    describe "#save"

    context "Marshalling" do
      describe "#_dump"
      describe "._load"
    end

    describe "#filename"
    describe "#reload"

    describe "#name" do
      it "returns name" do
        assert_equal "root", config.name
        assert_equal "context", config.all_children.first.name
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

    describe "#each" do
      context "given a block taking 2 parameters" do
        it "yields config and level" do
          config.each do |c,l|
            assert_kind_of described_class, c
            assert_kind_of Integer, l
          end
        end

        it "level starts at 0" do
          config.each do |_,level|
            assert_equal 0, level
            break
          end
        end

        context "starting from non-root element" do
          it "level still starts at 0" do
            child = config.all_children.first
            child.each do |_,level|
              assert_equal 0, level
              break
            end
          end
        end
      end

      context "given a block taking one paramater" do
        it "yields config only" do
          config.each do |*params|
            assert_equal 1, params.size
            assert_kind_of described_class, params.first
          end
        end
      end

      context "given a block which breaks" do
        it "calls block no more" do
          called = 0
          config.each { |_| called += 1; break }
          assert_equal 1, called
        end

        it "doesn't raise" do
          config.each { |_| break }
        end

        it "returns break value" do
          assert_nil config.each { |_| break }
          assert_equal :foo, config.each { |_| break :foo }
        end
      end

      context "given no a block" do
        let(:enum) { config.each }
        it "returns Enumerator" do
          assert_kind_of Enumerator, enum
        end

        it "the Enumerator yields config items only" do
          enum.each do |*params|
            assert_equal 1, params.size # no level parameter
            assert_kind_of described_class, params.first
          end
        end

        it "the Enumerator yields all config items" do
          assert_equal config.to_a.size, enum.size
        end
      end

      describe "#to_a" do
        let(:array) { config.to_a }
        it "returns config items" do
          array.each do |c|
            assert_kind_of described_class, c
          end
        end
        it "returns all config items including root element" do
          assert_equal 14, array.size
        end
      end

      context "given raising block" do
        it "calls block no more" do
          called = 0
          begin
            config.each { |config| called += 1; raise }
          rescue
            assert_equal 1, called
          end
        end

        let(:exception) { Class.new(RuntimeError) }
        it "raises" do
          assert_raises(exception) do
            config.each { raise exception }
          end
        end
      end
    end

    describe "#children" do
      it "returns all children" do
        assert_equal 13, config.all_children.size
      end
    end

    describe "#first_child" do
      context "with children" do
        let(:parent) { config.locate("/main/frontend/option") }
        let(:child) { parent.first_child }
        it "returns first child" do
          refute_nil child
          assert_equal "hwm", child.name
        end
      end
      context "with no children" do
        let(:parent) { config.locate("/main/frontend/option/swap") }
        it "returns nil" do
          assert_nil parent.first_child
        end
      end
    end

    describe "#siblings"

    describe "#locate" do
      context "given existing path" do
        let(:located_item) { config.locate("/main/frontend/option/swap") }
        it "returns config item" do
          assert_kind_of described_class, located_item
          assert_equal "swap", located_item.name
        end
      end

      context "given non-existent path" do
        let(:nonexistent_path) { "/foo/bar" }
        let(:located_item) { config.locate nonexistent_path }
        it "returns nil" do
          assert_nil located_item
        end
      end
    end

    describe "#last_at_depth"
  end
end
