require_relative '../../spec_helper'

describe CZTop::Config do
  describe "comments" do
    let(:config_contents) do
      <<-EOF
test
    has_no_comments
    has_one_comment
    has_two_comments
      EOF
    end
    let(:config) do
      c = CZTop::Config.from_string(config_contents)
      c.locate("test/has_one_comment").comments << "foo"
      c.locate("test/has_two_comments").comments << "foo" << "bar"
      c
    end
    let(:comments) { item.comments }

    describe "#comments" do
      let(:item) { config.locate("test") }
      it "returns CommentsAccessor" do
        assert_kind_of CZTop::Config::CommentsAccessor, comments
      end
    end

    describe CZTop::Config::CommentsAccessor do
      let(:item) { config.locate("test/has_no_comments") }

      describe "#<<" do
        let(:new_comment) { "foo bar" }
        before(:each) { comments << new_comment }
        it "adds a new comment" do
          assert_equal 1, comments.size
        end

        context "with malicious comment" do
          let(:new_comment) { "%s foo" }
          it "is safe" do # uses %s in comment
            assert_equal new_comment, comments.to_a.last
          end
        end
      end

      describe "#delete_all" do
        let(:item) { config.locate("test/has_two_comments") }
        it "removes all comments" do
          assert_equal 2, comments.size
          comments.delete_all
          assert_equal 0, comments.size
        end
      end

      describe "#size" do
        context "with no comment" do
          let(:item) { config.locate("test/has_no_comments") }
          it "returns zero" do
            assert_equal 0, comments.size
          end
        end
        context "with one comment" do
          let(:item) { config.locate("test/has_one_comment") }
          it "returns one" do
            assert_equal 1, comments.size
          end
        end
        context "with two comments" do
          let(:item) { config.locate("test/has_two_comments") }
          it "returns two" do
            assert_equal 2, comments.size
          end
        end
      end

      describe "#each" do
        let(:block) { ->(_){@called += 1} }
        before(:each) { @called = 0; comments.each(&block) }
        context "with no comment" do
          let(:item) { config.locate("test/has_no_comments") }
          it "does not call block" do
            assert_equal 0, @called
          end
          it "#to_a works correctly" do
            assert_empty comments.to_a
          end
        end
        context "with one comment" do
          let(:item) { config.locate("test/has_one_comment") }
          it "returns one" do
            assert_equal 1, @called
          end
          it "#to_a works correctly" do
            assert_equal %w[foo], comments.to_a
          end
        end
        context "with two comments" do
          let(:item) { config.locate("test/has_two_comments") }
          it "returns two" do
            assert_equal 2, @called
          end
          it "#to_a works correctly" do
            assert_equal %w[foo bar], comments.to_a
          end
        end
      end
    end

    describe "serialization" do
      let(:config) do
        root = described_class.new
        c = described_class.new "foo", root
        c.value = "bar"
        c.comments << "baz"
        c.comments << "bii"
        c
        root
      end
      context "when serializing" do
        let(:serialized) { config.to_s }
        it "serializes comments as well" do
          assert_match /#baz/, serialized
          assert_match /#bii/, serialized
        end
      end
      context "when loading" do
        let(:loaded_config) { described_class.from_string(config.to_s) }
        let(:comments) { loaded_config.locate("foo").comments }
        it "ignores comments" do
          assert_operator comments, :none?
        end
      end
    end
  end
end
