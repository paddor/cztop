# frozen_string_literal: true

require_relative '../../spec_helper'
require 'tempfile'

describe CZTop::Config do
  let(:config_contents) do
    <<~EOF
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
  let(:config) { CZTop::Config.from_string(config_contents) }


  describe '.from_string' do
    let(:loaded_config) { CZTop::Config.from_string(config_contents) }


    describe 'given a string containing config tree' do
      it 'returns a config' do
        assert_kind_of CZTop::Config, loaded_config
      end
    end
  end


  describe '#to_s' do
    it 'serializes the config tree to a string' do
      assert_kind_of String, config.to_s
    end

    it 'serializes correctly' do
      assert_equal config, CZTop::Config.from_string(config.to_s)
    end


    describe 'with only root element' do
      describe 'with no name' do
        let(:config) { CZTop::Config.new }

        it 'serializes to empty string' do
          assert_equal '', config.to_s
        end
      end


      describe 'with name and value set' do
        let(:config) do
          c = CZTop::Config.new('foo')
          c.value = 'bar'
          c
        end
        # NOTE: doesn't make a lot of sense to me
        it 'serializes to empty string' do
          assert_equal '', config.to_s
        end
      end
    end


    describe 'with root as parent' do
      let(:root) { CZTop::Config.new }


      describe 'with no name' do
        let(:config) { CZTop::Config.new nil, root }

        it 'serializes to the empty string' do
          assert_equal '', config.to_s
        end

        it 'even root serializes to the empty string' do
          assert_equal '', root.to_s
        end
      end


      describe 'with just a name' do
        let(:config_name) { 'foo' }
        let(:config) { CZTop::Config.new(config_name, parent: root) }

        it 'serializes to just the name' do
          assert_equal '', config.to_s
          assert_equal "#{config_name}\n", root.to_s
        end
      end


      describe 'with a name and a vaue' do
        let(:config_name) { 'foo' }
        let(:config_value) { 'bar' }
        let(:config) do
          c = CZTop::Config.new(config_name, parent: root)
          c.value = config_value
          c
        end

        it 'serializes to the full config item' do
          assert_equal '', config.to_s
          assert_equal "#{config_name} = \"#{config_value}\"\n", root.to_s
        end
      end
    end
  end


  describe '.load' do
    describe 'given config file' do
      let(:file) do
        file = Tempfile.new('zconfig_test')
        file.write(config_contents)
        file.rewind
        file
      end
      let(:filename) { file.path }
      let(:loaded_config) { CZTop::Config.load(filename) }

      it 'loads the file' do
        assert_kind_of CZTop::Config, loaded_config
        assert_equal filename, loaded_config.filename
      end


      describe '#reload' do
        describe 'loaded from file' do
          let(:fix_config) { CZTop::Config.from_string(config_contents) }


          describe 'when unchanged' do
            before { loaded_config.reload }

            it 'is still the same' do
              assert_equal fix_config, loaded_config
              assert_operator fix_config, :tree_equal?, loaded_config
            end
          end


          describe 'when changed' do
            before do
              changing_config = CZTop::Config.from_string(config_contents)
              changing_config['context/verbose'] = 0 # normally 1
              changing_config.save(filename) # overwrite existing file
              loaded_config.reload
            end

            it 'item is different' do
              refute_equal fix_config['context/verbose'], loaded_config['context/verbose']
            end

            it 'tree is different' do
              refute_operator fix_config, :tree_equal?, loaded_config
            end
          end


          describe 'when file has been deleted' do
            it 'raises' do
              loaded_config
              Pathname.new(filename).delete
              assert_raises(Errno::ENOENT) { loaded_config.reload }
            end
          end
        end


        describe 'created in-memory' do # or any other problem
          it 'raises' do
            assert_raises(TypeError) { config.reload }
          end
        end
      end


      describe '#filename' do
        describe 'root config item' do
          it 'returns filename' do
            assert_equal filename, loaded_config.filename
          end
        end


        describe 'child item' do
          let(:item) { loaded_config.locate('context/verbose') }

          it 'returns nil' do
            assert_nil item.filename
          end
        end
      end
    end


    describe 'given no config file' do
      let(:nonexistent_filename) { '/foo/bar.zpl' }

      it 'raises' do
        assert_raises(Errno::ENOENT) do
          CZTop::Config.load(nonexistent_filename)
        end
      end
    end
  end


  describe '#save' do
    let(:file) { Tempfile.new('zconfig_test') }
    let(:saved_file) do
      config.save(file.path)
      Pathname.new(file.path)
    end


    describe 'with empty config' do
      let(:config) { CZTop::Config.new }

      it 'saves' do
        assert_empty saved_file.read
      end
    end


    describe 'with empty config child' do
      before { config.children.new }

      it 'saves' do
        # NOTE: last line will be "(Unnamed)"
        assert_match(/^\(Unnamed\)$/, saved_file.read.lines.last)
      end
    end

    it 'saves to that file' do
      assert_operator saved_file, :size?
    end

    it 'saves correctly' do
      assert_equal config, CZTop::Config.load(saved_file.to_s)
    end


    describe 'with empty path' do
      it 'raises' do
        assert_raises(Errno::ENOENT) { config.save('') }
      end
    end


    describe 'with invalid path' do
      it 'raises' do
        assert_raises(Errno::EISDIR) { config.save('/tmp') }
      end
    end
  end


  describe 'Marshalling' do
    let(:marshaled) { Marshal.dump(config) }
    let(:unmarshaled) { Marshal.load(marshaled) }


    describe '#_dump and ._load' do
      it 'roundtrips' do
        assert_equal config, unmarshaled
      end
    end
  end
end
