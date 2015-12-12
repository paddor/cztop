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
        assert_nil parent_config.children.first
        config
        assert_equal config.to_ptr, parent_config.children.first.to_ptr
      end

      it "removes finalizer from delegate" do # parent will free it
        assert_nil config.ffi_delegate.instance_variable_get(:@finalizer)
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

        describe "#reload" do
          context "loaded from file" do
            let(:config2) { described_class.load(filename) }
            context "when unchanged" do
              before(:each) { loaded_config.reload }
              it "is still the same" do
                assert_equal config2, config
              end
            end
            context "when changed" do
              before(:each) do
                config2["context/verbose"] = 0
                config2.save(filename)
              end
              it "isn't the same anymore" do
                refute_equal config2, config
              end
            end
          end
          context "created in-memory" do # or any other problem
            it "raises" do
              assert_raises { config.reload }
            end
          end
        end
        describe "#filename" do
          context "root config item" do
            it "returns filename" do
              assert_equal filename, loaded_config.filename
            end
          end
          context "child item" do
            let(:item) { loaded_config.locate("context/verbose") }
            it "returns nil" do
              assert_nil item.filename
            end
          end
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

    describe "#save" do
      let(:file) { Tempfile.new("zconfig_test") }
      let(:saved_file) do
        config.save(file.path)
        Pathname.new(file.path)
      end
      it "saves to that file" do
        assert_operator saved_file, :size?
      end
      it "saves correctly" do
        assert_equal config, described_class.load(saved_file.to_s)
      end
    end

    context "Marshalling" do
      let(:marshaled) { Marshal.dump(config) }
      let(:unmarshaled) { Marshal.load(marshaled) }
      describe "#_dump and ._load" do
        it "roundtrips" do
          assert_equal config, unmarshaled
        end
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

    describe "#execute" do
      context "given a block" do
        it "yields config and level" do
          config.execute do |c,l|
            assert_kind_of described_class, c
            assert_kind_of Integer, l
          end
        end

        it "level starts at 0" do
          config.execute do |_,level|
            assert_equal 0, level
            break
          end
        end

        context "starting from non-root element" do
          it "level still starts at 0" do
            child = config.children.first
            child.execute do |_,level|
              assert_equal 0, level
              break
            end
          end
        end
      end

      context "given a block which breaks" do
        it "calls block no more" do
          called = 0
          config.execute { |_| called += 1; break }
          assert_equal 1, called
        end

        it "doesn't raise" do
          config.execute { |_| break }
        end

        it "returns break value" do
          assert_nil config.execute { |_| break }
          assert_equal :foo, config.execute { |_| break :foo }
        end
      end


      context "given raising block" do
        it "calls block no more" do
          called = 0
          begin
            config.execute { |config| called += 1; raise }
          rescue
            assert_equal 1, called
          end
        end

        let(:exception) { Class.new(RuntimeError) }
        it "raises" do
          assert_raises(exception) do
            config.execute { raise exception }
          end
        end
      end
    end

    describe "#children" do
      let(:parent) { config }
      let(:children) { parent.children }
      it "returns SiblingsAccessor" do
        assert_kind_of CZTop::Config::SiblingsAccessor, children
      end

      context "with children" do
        let(:parent) { config.locate("/main/frontend/option") }
        it "returns first child" do
          refute_nil children.first
          assert_equal "hwm", children.first.name
        end
        it "returns all children" do
          assert_equal %w[hwm swap], children.to_a.map(&:name)
        end
      end
      context "with no children" do
        let(:parent) { config.locate("/main/frontend/option/swap") }
        it "has no children" do
          assert_nil parent.children.first
          assert_empty parent.children.to_a
        end
      end
    end

    describe "#siblings" do
      let(:item) { config }
      let(:siblings) { item.siblings }
      it "returns SiblingsAccessor" do
        assert_kind_of CZTop::Config::SiblingsAccessor, siblings
      end
      context "with no siblings" do
        it "has no siblings" do
          refute_operator siblings, :any?
          assert_equal 0, siblings.count
          assert_nil siblings.first
        end
      end
      context "with siblings" do
        let(:item) { config.locate("main/frontend/option") }
        it "has siblings" do
          assert_operator siblings, :any?
        end
        it "returns correct first sibling" do
          assert_equal config.locate("main/frontend/bind"), siblings.first
        end
        it "returns all siblings" do
          assert_equal 2, siblings.count
        end
        it "returns siblings as Config objects" do
          siblings.each { |s| assert_kind_of CZTop::Config, s }
        end
      end
      context "with no younger siblings" do
        # has only an "older" sibling
        let(:item) { config.locate("main/backend") }
        it "acts like it has no siblings" do
          assert_empty siblings.to_a
          assert_nil siblings.first
        end
      end
    end

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

    describe "#last_at_depth" do
      let(:found) { config.last_at_depth(level) }
      context "with level 0" do
        let(:level) { 0 }
        let(:expected) { config }
        it "finds correct item" do
          assert_equal expected, found
        end
      end
      context "with level 1" do
        let(:level) { 1 }
        let(:expected) { config.locate("main") }
        it "finds correct item" do
          assert_equal expected, found
        end
      end
      context "with level 2" do
        let(:level) { 2 }
        let(:expected) { config.locate("main/backend") }
        it "finds correct item" do
          assert_equal expected, found
        end
      end
      context "with level 99" do
        let(:level) { 99 }
        let(:expected) { nil }
        it "returns nil" do
          assert_equal expected, found
        end
      end
    end
  end
end
