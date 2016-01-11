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

  after(:each) { actor.terminate }
  let(:actor) do
    CZTop::Actor.new do |msg, pipe|
      received_messages << msg.to_a
      yielded << [msg, pipe]
    end
  end
  let(:received_messages) { [] }
  let(:yielded) { [] }

  describe "#initialize" do

    before(:each) do
      expect(::CZMQ::FFI::Zactor).to receive(:new)
        .with(kind_of(FFI::Pointer), nil)
        .and_call_original
      expect_any_instance_of(CZTop::Actor).to receive(:attach_ffi_delegate)
        .with(kind_of(::CZMQ::FFI::Zactor))
        .and_call_original
      expect_any_instance_of(CZTop::Actor).to receive(:mk_callback_shim)
        .and_call_original
    end

    let(:callback_shim) { actor.instance_variable_get(:@callback) }

    context "with C callback" do # pointer to C function
      let(:c_function) { CZTop::Beacon::ZBEACON_FPTR }
      let(:actor) { CZTop::Actor.new(c_function) }

      it "doesn't shim it" do
        assert_same c_function, callback_shim
      end
    end

    context "with Proc callback" do
      let(:proc_) do
        lambda do |msg, pipe|
          received_messages << msg.to_a
          yielded << [msg, pipe]
        end
      end
      let(:actor) do
        CZTop::Actor.new(proc_)
      end
      it "shims it" do
        refute_nil callback_shim
        refute_same proc_, callback_shim
      end

      it "works" do
        actor << "FOO"
        actor.terminate
        assert_equal [["FOO"]], received_messages
      end
    end

    context "with block" do
      # can use default actor
      it "works" do
        actor << "FOO"
        actor.terminate
        assert_equal [["FOO"]], received_messages
      end
    end
  end

  describe "#mk_callback_shim" do
    context "with invalid handler" do
      it "raises" do
        assert_raises(ArgumentError) { actor.__send__(:mk_callback_shim, "foo") }
      end
    end

    context "with faulty handler" do
      let(:actor) { CZTop::Actor.new { raise "foobar" } }
      it "warns about it" do
        assert_output nil, /handler.*raised exception/i do
          actor << "foo"
          actor.terminate
        end
      end
    end
  end

  describe "#send_picture" do
    let(:ffi_delegate) { actor.ffi_delegate }
    let(:picture) { "si" }
    let(:ffi_args) { [ :string, "foo", :int, 42 ] }
    it "sends picture" do
      expect(::CZMQ::FFI::Zsock).to receive(:send)
        .with(ffi_delegate, picture, *ffi_args)
      actor.send_picture(picture, *ffi_args)
    end

    context "with dead actor" do
      before(:each) { actor.terminate }
      it "raises DeadActorError" do
        assert_raises(CZTop::Actor::DeadActorError) do
          actor.send_picture("s", :string, "foo")
        end
      end
    end
  end

  describe "#wait" do
    let(:actor) do
      CZTop::Actor.new do |msg, pipe|
        case msg[0]
        when "SIGNAL0"
          pipe.signal(0)
        when "SIGNAL1"
          pipe.signal(1)
        end
      end
    end

    it "waits for signal" do
      actor << "SIGNAL0"
      assert_equal 0, actor.wait
      actor << "SIGNAL1"
      assert_equal 1, actor.wait
    end
  end

  describe "#process_messages" do
    it "breaks on $TERM" do
      # can't use #<<
      actor.instance_eval do
        @zactor_mtx.synchronize do
          CZTop::Message.new("$TERM").send_to(self)
        end
      end
      begin
        actor << "foo"
      rescue CZTop::Actor::DeadActorError
        # that's okay
      end
      sleep 0.01 until actor.terminated?
      assert_empty received_messages
    end

    context "when interrupted" do
      it "terminates actor" do
        expect(actor).to receive(:next_message).and_raise(Interrupt).once
        begin
          actor << "foo" << "INTERRUPTED" << "bar"
        rescue CZTop::Actor::DeadActorError
          # that's okay
        end
        start_time = Time.now
        until actor.terminated?
          sleep 0.01
          if start_time + 1 < Time.now
            warn "test example hanging"
            warn "received messages so far: #{received_messages.inspect}"
            warn "terminating actor manually"
            actor.terminate
          end
        end
        refute_includes received_messages, ["bar"]
      end
    end

    it "yields message and pipe" do
      actor << "foo"
      actor.terminate
      assert_equal 2, yielded[0].size
      assert_kind_of CZTop::Message, yielded[0][0]
      assert_kind_of CZTop::Socket::PAIR, yielded[0][1]
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

    context "threads" do
      let(:mutex) { actor.instance_variable_get(:@zactor_mtx) }
      it "is thread-safe" do
        expect(mutex).to receive(:synchronize).at_least(1)
          .and_call_original
        actor << "foo"
      end
    end

    context "with commands" do
      let(:commands) { %w[ PRINT SHOW DO ] }
      let(:received_commands) do
        received_messages.map(&:first)
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
      let(:msg) { %w[ SHOW foo bar ] }

      before(:each) do
        actor << msg
        actor.terminate
      end

      it "sends one message" do
        assert_equal 1, received_messages.size
        assert_equal msg, received_messages.first
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

    context "with $TERM" do
      it "calls #terminate" do
        # one more call from the #after filter
        expect(actor).to receive(:terminate).twice.and_call_original
        actor << "$TERM"
        assert_operator actor, :terminated?
      end
    end
  end

  describe "#receive" do
    let(:actor) do
      # echo actor
      CZTop::Actor.new do |msg, pipe|
        pipe << msg
      end
    end

    context "threads" do
      let(:mutex) { actor.instance_variable_get(:@zactor_mtx) }
      it "is thread-safe" do
        expect(mutex).to receive(:synchronize).at_least(1)
          .and_call_original
        actor << "foo"
        actor.receive
      end
    end

    context "with messages available" do
      before(:each) do
        actor << "foo" << "bar"
      end

      it "returns messages" do
        assert_equal "foo", actor.receive[0]
        assert_equal "bar", actor.receive[0]
      end
    end

    context "with dead actor" do
      before(:each) { actor.terminate }
      it "raises DeadActorError" do
        assert_raises(CZTop::Actor::DeadActorError) do
          actor.receive
        end
      end
    end
  end

  describe "#request" do
    let(:actor) do
      CZTop::Actor.new do |msg, pipe|
        pipe << msg.to_a.map{|s| s.downcase }
      end
    end
    let(:word) { "FOO" }
    let(:response) do
      actor.request(word).to_a[0]
    end
    it "returns response" do
      assert_equal word.downcase, response
    end

    context "threads" do
      let(:mutex) { actor.instance_variable_get(:@zactor_mtx) }
      it "is thread-safe" do
        expect(mutex).to receive(:synchronize).at_least(1)
          .and_call_original
        response
      end
    end
    context "with dead actor" do
      before(:each) { actor.terminate }
      it "raises DeadActorError" do
        assert_raises(CZTop::Actor::DeadActorError) do
          response
        end
      end
    end

    context "with $TERM message" do
      let(:word) { "$TERM" }
      it "raises" do
        assert_raises(ArgumentError) do
          response
        end
      end
    end
  end

  describe "#terminate" do
    context "when actor is alive" do
      it "tells actor to terminate" do
        msg = CZTop::Message.new "$TERM"
        expect(CZTop::Message).to receive(:new).with("$TERM").and_return(msg)
        expect(msg).to receive(:send_to).with(actor).and_call_original
        actor.terminate
      end

      it "returns true" do
        assert_equal true, actor.terminate
      end

      it "waits for handler to terminate" do
        expect(actor.instance_variable_get(:@handler_dead_signal)).to(
          receive(:pop).and_call_original)
        actor.terminate
      end

      context "with slow handler death" do
        let(:handler_thread) { actor.instance_variable_get(:@handler_thread) }
        it "waits repeatedly" do
          checked = 0
          expect(handler_thread).to receive(:alive?) do
            checked += 1
            checked < 5 # handler thread will be alive for a while
          end.exactly(5)
          expect(actor).to receive(:sleep).exactly(4)
          actor.terminate
        end
      end
    end

    context "with dead actor" do
      before(:each) { actor.terminate }

      it "returns false" do
        assert_equal false, actor.terminate
      end
    end
  end
end
