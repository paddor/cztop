# frozen_string_literal: true

require_relative 'spec_helper'

describe CZTop::Config do
  describe '#initialize' do
    describe 'with a name' do
      let(:config_name) { 'foo' }
      let(:config) { CZTop::Config.new config_name }

      it 'sets that name' do
        assert_equal config_name, config.name
      end
    end


    describe 'with no name' do
      let(:config) { CZTop::Config.new }

      it 'creates a config item anyway' do
        assert_kind_of CZTop::Config, config
      end

      it 'has nil name' do
        assert_nil config.name
      end
    end


    describe 'with name and value' do
      let(:config_name) { 'foo' }
      let(:config_value) { 'bar' }
      let(:config) { CZTop::Config.new config_name, config_value }

      it 'sets name and value' do
        assert_equal config_name, config.name
        assert_equal config_value, config.value
      end
    end


    describe 'given a parent' do
      let(:parent_name) { 'foo' }
      let(:parent_config) { CZTop::Config.new parent_name }
      let(:config_name) { 'bar' }
      let(:config) { CZTop::Config.new config_name, parent: parent_config }

      it 'appends it to that parent' do
        assert_nil parent_config.children.first
        config
        assert_equal config.to_ptr, parent_config.children.first.to_ptr
      end

      it 'removes finalizer from delegate' do # parent will free it
        assert_nil config.ffi_delegate.instance_variable_get(:@finalizer)
      end
    end


    describe 'with no parent' do
      let(:config) { CZTop::Config.new }

      it "doesn't remove finalizer from delegate" do
        refute_nil config.ffi_delegate.instance_variable_get(:@finalizer)
      end
    end


    describe 'with a block' do
      it 'yields self' do
        yielded = nil
        config = CZTop::Config.new { |c| yielded = c }
        assert_same config, yielded
      end
    end
  end


  describe 'given a config' do
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


    describe '#inspect' do
      it 'has a nice output' do
        assert_match(/Config.+name=.+value=/, config.inspect)
      end
    end


    describe '#==' do
      let(:this_name) { 'foo' }
      let(:this_value) { 'bar' }
      let(:this) { CZTop::Config.new(this_name, this_value) }


      describe 'with equal config' do
        let(:that) { CZTop::Config.new(this_name, this_value) }

        it 'is equal' do
          assert_operator this, :==, that
          assert_operator that, :==, this
        end
      end


      describe 'with different config' do
        let(:that_name) { 'quu' }
        let(:that_value) { 'quux' }


        describe 'with different name' do
          let(:that) { CZTop::Config.new(that_name, this_value) }

          it 'is not equal' do
            refute_operator this, :==, that
            refute_operator that, :==, this
          end
        end


        describe 'with different value' do
          let(:that) { CZTop::Config.new(this_name, that_value) }

          it 'is not equal' do
            refute_operator this, :==, that
            refute_operator that, :==, this
          end
        end
      end
    end


    describe '#tree_equal?' do
      describe 'given equal config tree' do
        let(:this) { config.locate('main/frontend') }
        let(:other) { CZTop::Config.from_string(config_contents) }
        let(:that) { other.locate('main/frontend') }

        it 'is tree equal' do
          # mangle an independent side-tree a bit
          backend = config.locate('main/backend')
          backend.name = 'foobar'
          backend.children.new('foo', 'bar')
          assert_operator this, :tree_equal?, that
          assert_operator that, :tree_equal?, this
        end
      end


      describe 'given different config tree' do
        let(:other_config) { CZTop::Config.new('foo') }

        it 'is not tree equal' do
          refute_operator config, :tree_equal?, other_config
          refute_operator other_config, :tree_equal?, config
        end
      end
    end


    describe '#name' do
      describe 'with named elements' do
        it 'returns name' do
          assert_equal 'root', config.name
          assert_equal 'context', config.children.first.name
        end
      end


      describe 'with unnamed elements' do
        it 'returns nil' do
          assert_nil config.children.new.name
        end
      end
    end


    describe '#name=' do
      let(:new_name) { 'foo' }

      it 'sets name' do
        config.name = new_name
        assert_equal new_name, config.name
      end
    end


    describe '#value' do
      let(:config_contents) do
        <<~EOF
          a = 1
          b = ""
          c
              d = "foo"
              f = bar
              g
              h # no value either
        EOF
      end


      describe 'with no value' do
        let(:item) { config.locate('/c/g') }

        it 'returns the empty string' do
          assert_empty item.value
        end
      end


      describe 'with value' do
        let(:paths_values) do
          { 'a' => '1',
            'b' => '',
            'c' => '',
            'c/d' => 'foo',
            'c/f' => 'bar',
            'c/g' => '',
            'c/h' => '' }
        end

        it 'reads value' do
          paths_values.each do |path, expected|
            assert_equal expected, config.locate(path).value
          end
        end
      end
    end


    describe '#value=' do
      let(:item) { config.locate('main/frontend/option/hwm') }
      before { item.value = new_value }


      describe 'given safe string' do
        let(:new_value) { 'foo bar' }

        it 'sets value' do
          assert_equal new_value, item.value
        end
      end


      describe 'given integer' do
        let(:new_value) { 555 }

        it 'sets value' do
          assert_equal new_value.to_s, item.value
        end
      end


      describe 'given unsafe, user-supplied value' do
        let(:new_value) { '%s' }

        it 'sets value' do
          assert_equal new_value, item.value
        end
      end
    end


    describe '#[]=' do
      describe 'given a path and value' do
        let(:path) { 'main/type' }
        let(:new_value) { 'foobar' }

        it "changes the item's value" do
          refute_equal new_value, config[path]
          config[path] = new_value
          assert_equal new_value, config[path]
        end

        it 'has alias #put' do
          config.put(path, new_value)
          assert_equal new_value, config[path]
        end
      end
    end


    describe '#[]' do
      describe 'given existing path' do
        describe 'with value set' do
          let(:path) { 'main/type' }

          it 'returns correct value' do
            assert_equal 'zqueue', config.get(path)
          end

          it 'has alias #get' do
            assert_equal config[path], config.get(path)
          end
        end


        describe 'with no value set' do
          let(:path) { 'main/frontend' }

          it 'returns the empty string' do
            assert_empty config[path]
          end


          describe 'given default value' do
            let(:default) { 'my default value' }

            it 'returns empty string' do
              assert_empty config[path, default]
            end
          end
        end
      end


      describe 'given non-existent path' do
        let(:path) { 'main/foobar' }

        it 'returns the empty string' do
          assert_empty config[path]
        end


        describe 'given default value' do
          let(:default) { 'my default value' }

          it 'returns default value' do
            assert_equal default, config[path, default]
          end
        end
      end
    end
  end
end
