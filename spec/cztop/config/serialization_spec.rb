require_relative '../../spec_helper'
require 'tempfile'

describe CZTop::Config do
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
        let(:config) { described_class.new(name, parent: root) }
        it "serializes to just the name" do
          assert_equal "", config.to_s
          assert_equal "#{name}\n", root.to_s
        end
      end
      context "with a name and a vaue" do
        let(:name) { "foo" }
        let(:value) { "bar" }
        let(:config) do
          c = described_class.new(name, parent: root)
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
          let(:fix_config) { described_class.from_string(config_contents) }
          context "when unchanged" do
            before { loaded_config.reload }
            it "is still the same" do
              assert_equal fix_config, loaded_config
              assert_operator fix_config, :tree_equal?, loaded_config
            end
          end
          context "when changed" do
            before do
              changing_config = described_class.from_string(config_contents)
              changing_config["context/verbose"] = 0 # normally 1
              changing_config.save(filename) # overwrite existing file
              loaded_config.reload
            end
            it "item is different" do
              refute_equal fix_config["context/verbose"], loaded_config["context/verbose"]
            end
            it "tree is different" do
              refute_operator fix_config, :tree_equal?, loaded_config
            end
          end
          context "when file has been deleted" do
            it "raises" do
              loaded_config
              Pathname.new(filename).delete
              assert_raises(Errno::ENOENT) { loaded_config.reload }
            end
          end
        end
        context "created in-memory" do # or any other problem
          it "raises" do
            assert_raises(TypeError) { config.reload }
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
      it "raises" do
        assert_raises(Errno::ENOENT) do
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
    context 'with empty config' do
      let(:config) { described_class.new }
      it 'saves' do
        assert_empty saved_file.read
      end
    end
    context 'with empty config child' do
      before { config.children.new }
      it 'saves' do
        # NOTE: last line will be "(Unnamed)"
        assert_match /^\(Unnamed\)$/, saved_file.read.lines.last
      end
    end

    it "saves to that file" do
      assert_operator saved_file, :size?
    end
    it "saves correctly" do
      assert_equal config, described_class.load(saved_file.to_s)
    end
    context "with empty path" do
      it "raises" do
        assert_raises(Errno::ENOENT) { config.save("") }
      end
    end
    context "with invalid path" do
      it "raises" do
        assert_raises(Errno::EISDIR) { config.save("/") }
      end
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
end
