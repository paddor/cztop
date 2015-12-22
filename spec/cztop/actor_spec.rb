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
    CZTop::Actor.new do |command, pipe_delegate|
      received << command
    end
  end
  let(:received) { [] }

  describe "#initialize" do
    context "with callback given" do
      it "remembers callback"
    end

    context "with no FFI callback given" do
      context "with block given" do
        it "remembers it as task"
      end
      context "with no block given" do
        it "raises"
      end
    end
  end

  describe "#callback" do
  end

  describe "#<<" do
    it "sends commands to actor" do
      actor << "PRINT"
      actor << %w[SHOW foo bar]
      actor << %w[DO foo bar]
      actor.terminate
      assert_equal %w[ PRINT SHOW DO ], received
    end

    context "when actor is dead" do
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

    context "when actor is dead" do
      before(:each) { actor.terminate }

      it "raises DeadActorError" do
        assert_raises(CZTop::Actor::DeadActorError) do
          actor.terminate
        end
      end
    end
  end
end
