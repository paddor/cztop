require_relative 'spec_helper'

describe CZTop::Actor do
  include_examples "has FFI delegate"

  it "has Zsock options" do
    assert_operator described_class, :<, CZTop::ZsockOptions
  end

  it "has send/receive methods" do
    assert_operator described_class, :<, CZTop::SendReceiveMethods
  end

  it "has polymorphic Zsock methods" do
    assert_operator described_class, :<, CZTop::PolymorphicZsockMethods
  end

  let(:actor) do
    CZTop::Actor.new do |msg, pipe_delegate|
      received_messages << msg
    end
  end
  let(:received_messages) { [] }

  describe "#initialize" do
    let(:ffi_delegate) { double "ffi delegate" }
    let(:ffi_callback) { double("ffi callback") }

    before(:each) do
      expect(::CZMQ::FFI::Zactor).to receive(:new).with(ffi_callback, nil)
        .and_return(ffi_delegate)
      expect_any_instance_of(CZTop::Actor).to receive(:attach_ffi_delegate)
        .with(ffi_delegate)
    end

    context "with FFI callback" do
      let(:actor) { CZTop::Actor.new(ffi_callback) }

      it "remembers callback" do
        assert_same ffi_callback, actor.instance_variable_get(:@callback)
      end

      it "doesn't create another callback" do
        expect_any_instance_of(CZTop::Actor).not_to receive(:make_default_callback)
        actor
      end
    end

    context "with no FFI callback given" do
      let(:actor) { CZTop::Actor.new {} }

      before(:each) do
        expect_any_instance_of(CZTop::Actor).to receive(:make_default_callback)
          .and_return(ffi_callback)
      end

      it "creates a default callback" do
        actor
      end
    end
  end

  describe "#make_default_callback" do
    let(:actor) do
      CZTop::Actor.new do |*args|
        yielded.replace(args)
        received_messages << args[0]
      end
    end
    let(:yielded) { [] }
    let(:received_messages) { [] }

    it "recognizes $TERM" do
      actor.terminate
      pass
    end

    context "with no block" do
      it "raises" do
        assert_raises(ArgumentError) { actor.__send__(:make_default_callback) }
      end
    end

    context "when interrupted" do
      it "terminates actor" do
        expect(actor).to receive(:next_message).and_raise(Interrupt).once
        actor << "foo"
        actor.__send__(:wait)
        assert_operator actor, :terminated?
      end
    end

    it "yields message and pipe" do
      actor << "foo"
      actor.terminate
      assert_equal 2, yielded.size
      assert_kind_of CZTop::Message, yielded[0]
      assert_kind_of CZTop::Socket::PAIR, yielded[1]
    end
  end

  describe "#terminated?" do
    context "when terminated" do
      it "returns true" do
        actor.terminate
        assert actor.terminated?
      end
    end
    context "when not yet terminated" do
      it "returns false" do
        refute actor.terminated?
        actor.terminate
      end
    end
  end

  describe "#<<" do

    let(:actor) do
      CZTop::Actor.new {}
    end

    context "with commands" do
      let(:commands) { %w[ PRINT SHOW DO ] }
      let(:received_commands) do
        received_messages.map { |msg| msg.frames.first.to_s }
      end
      before(:each) do
        commands.each { |c| actor << c }
        actor.terminate
      end
      it "sends commands to actor" do
        assert_equal commands, received_commands
      end
    end

    it "returns self" do # so it can be chained
      assert_same actor, actor << "foo"
    end

    context "with array" do
      let(:actor) do
        CZTop::Actor.new do |msg, pipe|
          received_messages << msg
        end
      end
      let(:received_messages) { [] }
      let(:msg) { %w[ SHOW foo bar ] }

      before(:each) do
        actor << msg
        actor.terminate
      end

      it "sends one message" do
        assert_equal 1, received_messages.size
        assert_equal msg, received_messages.first.frames.map(&:to_s)
      end
    end

    context "with dead actor" do
      before(:each) { actor.terminate }
      it "raises DeadActorError" do
        assert_raises(CZTop::Actor::DeadActorError) do
          actor << "FOO"
        end
      end
    end
  end

  describe "#terminate" do
    context "when actor is alive" do
      it "tells actor to terminate" do
        expect(actor).to receive(:<<).with("$TERM").and_call_original
        actor.terminate
      end

      it "waits for death signal" do
        expect(actor).to receive(:wait).and_call_original
        actor.terminate
      end
    end

    context "with dead actor" do
      before(:each) { actor.terminate }

      it "raises DeadActorError" do
        assert_raises(CZTop::Actor::DeadActorError) do
          actor.terminate
        end
      end
    end
  end
end
