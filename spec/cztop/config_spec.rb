require_relative '../spec_helper'
require 'tempfile'

describe CZTop::Config do

  context "given a config file" do
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

    describe "#initialize" do
      context "given a name" do
        it "sets that name"
        context "given a parent" do
          it "appends it to that parent"
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
      context "given config item that has no value" do
        let(:item) { config.locate("/main/backend") }
        it "returns the empty string" do
          assert_empty item.value
        end
      end

      context "given config item that has value" do
        let(:item) { config.locate("/main/backend/bind") }
        let(:expected_value) { "inproc:@@//@@addr3" }
        it "reads value" do
          assert_equal expected_value, item.value
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
            child = config.children.first
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
          begin
            config.each { |_| called += 1; break }
          rescue
            assert_equal 1, called
          end
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
        assert_equal 13, config.children.size
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
    describe "#comments"
    describe "#add_comment"
    describe "#delete_comments"
  end
end

describe CZTop::Config::Comments do
  describe "#<<"
  describe "#delete_all"
  describe "#each"
end