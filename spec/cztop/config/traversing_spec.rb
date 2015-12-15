require_relative '../../spec_helper'

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
          config.execute { |_| called += 1; raise }
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
      assert_kind_of CZTop::Config::ChildrenAccessor, children
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

    context "adding a new child" do
      let(:new_child) { children.new }
      it "returns new child" do
        assert_kind_of CZTop::Config, new_child
      end
      it "adds new child" do
        new_child
        assert_equal 2+1, children.count
        assert_equal new_child, parent.last_at_depth(1)
      end
      context "with name" do
        let(:name) { "foo" }
        it "sets name" do
          assert_equal name, children.new(name).name
        end
      end
      context "with name and value" do
        let(:name) { "foo" }
        let(:value) { "bar" }
        let(:new_child) { children.new(name, value) }
        it "sets name and value" do
          assert_equal name, new_child.name
          assert_equal value, new_child.value
        end
      end
      context "with block given" do
        it "yields new child" do
          yielded = nil
          new_child = children.new { |c| yielded = c }
          assert_same new_child, yielded
        end
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
