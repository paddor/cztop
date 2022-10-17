# frozen_string_literal: true

require_relative 'spec_helper'

describe CZTop::Actor do
  include_examples 'has FFI delegate'

  it 'has Zsock options' do
    assert_operator described_class, :<, CZTop::ZsockOptions
  end

  it 'has send/receive methods' do
    assert_operator described_class, :<, CZTop::SendReceiveMethods
  end

  it 'has polymorphic Zsock methods' do
    assert_operator described_class, :<, CZTop::PolymorphicZsockMethods
  end

  after { actor.terminate }
  let(:actor) do
    CZTop::Actor.new do |msg, pipe|
      received_messages << msg.to_a
      yielded << [msg, pipe]
    end
  end
  let(:received_messages) { [] }
  let(:yielded) { [] }

  describe '#initialize' do
    before do
      expect(::CZMQ::FFI::Zactor).to receive(:new)
        .with(kind_of(FFI::Pointer), nil)
        .and_call_original
      expect_any_instance_of(CZTop::Actor).to receive(:attach_ffi_delegate)
        .with(kind_of(::CZMQ::FFI::Zactor))
        .and_call_original
    end

    let(:callback_shim) { actor.instance_variable_get(:@callback) }

    context 'with C callback' do # pointer to C function
      let(:c_function) { CZTop::Beacon::ZBEACON_FPTR }
      let(:actor) { CZTop::Actor.new(c_function) }

      it "doesn't shim it" do
        assert_same c_function, callback_shim
      end
    end

    context 'with Proc callback' do
      let(:proc_) do
        lambda do |msg, pipe|
          received_messages << msg.to_a
          yielded << [msg, pipe]
        end
      end
      let(:actor) do
        CZTop::Actor.new(proc_)
      end
      before do
        expect_any_instance_of(CZTop::Actor).to receive(:shim)
          .and_call_original
      end
      it 'shims it' do
        refute_nil callback_shim
        refute_same proc_, callback_shim
      end

      it 'works' do
        actor << 'FOO'
        actor.terminate
        assert_equal [['FOO']], received_messages
      end
    end

    context 'with block' do
      # can use default actor
      it 'works' do
        actor << 'FOO'
        actor.terminate
        assert_equal [['FOO']], received_messages
      end
    end
  end

  describe '#shim' do
    context 'with invalid handler' do
      it 'raises' do
        assert_raises(ArgumentError) { actor.__send__(:shim, 'foo') }
      end
    end

    context 'with faulty handler' do
      let(:error) { RuntimeError.new('foobar') }
      let(:actor) { CZTop::Actor.new { raise error } }
      before do
        actor << 'foo'
        actor.terminate
      end
      it 'stores exception' do
        assert_same error, actor.exception
      end
    end
  end

  describe '#crashed?' do
    before do
      actor << 'foo'
      actor.terminate
    end
    context 'with crashed actor' do
      let(:actor) { CZTop::Actor.new { raise } }
      it 'returns true' do
        assert_operator actor, :crashed?
      end
    end
    context 'with normally terminated actor' do
      it 'returns true' do
        refute_operator actor, :crashed?
      end
    end
  end

  describe '#exception' do
    before do
      actor << 'foo'
      actor.terminate
    end
    context 'with crashed actor' do
      let(:error) { RuntimeError.new('foobar') }
      let(:actor) { CZTop::Actor.new { raise error } }
      it 'returns stored exception' do
        assert_same error, actor.exception
      end
    end
    context 'with alive actor' do
      it 'returns nil' do
        assert_nil actor.exception
      end
    end
    context 'with normally terminated actor' do
      it 'returns nil' do
        assert_nil actor.exception
      end
    end
  end

  describe '#send_picture' do
    let(:ffi_delegate) { actor.ffi_delegate }
    let(:picture) { 'si' }
    let(:ffi_args) { [:string, 'foo', :int, 42] }
    it 'sends picture' do
      expect(::CZMQ::FFI::Zsock).to receive(:send)
        .with(ffi_delegate, picture, *ffi_args)
      actor.send_picture(picture, *ffi_args)
    end

    context 'with dead actor' do
      before { actor.terminate }
      it 'raises DeadActorError' do
        assert_raises(CZTop::Actor::DeadActorError) do
          actor.send_picture('s', :string, 'foo')
        end
      end
    end
  end

  describe '#wait' do
    let(:actor) do
      CZTop::Actor.new do |msg, pipe|
        case msg[0]
        when 'SIGNAL0'
          pipe.signal(0)
        when 'SIGNAL1'
          pipe.signal(1)
        end
      end
    end

    it 'waits for signal' do
      actor << 'SIGNAL0'
      assert_equal 0, actor.wait
      actor << 'SIGNAL1'
      assert_equal 1, actor.wait
    end
  end

  describe '#process_messages' do
    context 'when sending $TERM' do
      before do
        # can't use #<<
        actor.instance_eval do
          @mtx.synchronize do
            CZTop::Message.new('$TERM').send_to(self)
          end
        end
      end

      it 'breaks' do
        begin
          actor << 'foo'
        rescue CZTop::Actor::DeadActorError
          # that's okay
        end

        actor.terminate # idempotent
        assert_empty received_messages
      end
    end

    context 'when interrupted' do
      before do
        expect(actor).to receive(:next_message).and_raise(Interrupt).once
      end
      it 'terminates actor' do
        begin
          actor << 'foo' << 'INTERRUPTED' << 'bar'
        rescue CZTop::Actor::DeadActorError
          # that's okay
        end
        actor.terminate # idempotent
        refute_includes received_messages, ['bar']
      end
    end

    it 'yields message and pipe' do
      actor << 'foo'
      actor.terminate
      assert_equal 2, yielded[0].size
      assert_kind_of CZTop::Message, yielded[0][0]
      assert_kind_of CZTop::Socket::PAIR, yielded[0][1]
    end
  end

  describe '#dead?' do
    context 'when terminated' do
      it 'returns true' do
        actor.terminate
        assert actor.dead?
      end
    end
    context 'when not yet terminated' do
      it 'returns false' do
        refute actor.dead?
      end
    end
  end

  describe '#<<' do
    context 'threads' do
      let(:mutex) { actor.instance_variable_get(:@mtx) }
      it 'is thread-safe' do
        expect(mutex).to receive(:synchronize).at_least(:once)
                                              .and_call_original
        actor << 'foo'
      end
    end

    context 'with commands' do
      let(:commands) { %w[PRINT SHOW DO] }
      let(:received_commands) do
        received_messages.map(&:first)
      end
      before do
        commands.each { |c| actor << c }
        actor.terminate
      end
      it 'sends commands to actor' do
        assert_equal commands, received_commands
      end
    end

    it 'returns self' do # so it can be chained
      assert_same actor, actor << 'foo'
    end

    context 'with array' do
      let(:msg) { %w[SHOW foo bar] }

      before do
        actor << msg
        actor.terminate
      end

      it 'sends one message' do
        assert_equal 1, received_messages.size
        assert_equal msg, received_messages.first
      end
    end

    context 'with dead actor' do
      before { actor.terminate }
      it 'raises DeadActorError' do
        assert_raises(CZTop::Actor::DeadActorError) do
          actor << 'FOO'
        end
      end
    end

    context 'with $TERM' do
      it 'calls #terminate' do
        # one more call from the #after filter
        expect(actor).to receive(:terminate).twice.and_call_original
        actor << '$TERM'
      end
      it 'is synchronous' do
        actor << '$TERM'
        assert_operator actor, :dead?
      end
    end

    context 'sndtimeo reached' do
      let(:msg) { CZTop::Message.new('foobar') }
      after { actor << msg }
      it 'retries' do
        expect(msg).to receive(:send_to)
          .with(actor).and_raise(IO::EAGAINWaitWritable).ordered
        expect(msg).to receive(:send_to)
          .with(actor).at_least(:once).and_call_original.ordered
      end
    end
  end

  describe '#receive' do
    let(:actor) do
      # echo actor
      CZTop::Actor.new do |msg, pipe|
        pipe << msg
      end
    end

    context 'threads' do
      let(:mutex) { actor.instance_variable_get(:@mtx) }
      it 'is thread-safe' do
        expect(mutex).to receive(:synchronize).at_least(:once)
                                              .and_call_original
        actor << 'foo'
        actor.receive
      end
    end

    context 'with messages available' do
      before do
        actor << 'foo' << 'bar'
      end

      it 'returns messages' do
        assert_equal 'foo', actor.receive[0]
        assert_equal 'bar', actor.receive[0]
      end
    end

    context 'with dead actor' do
      before { actor.terminate }
      it 'raises DeadActorError' do
        assert_raises(CZTop::Actor::DeadActorError) do
          actor.receive
        end
      end
    end
  end

  describe '#request' do
    let(:actor) do
      CZTop::Actor.new do |msg, pipe|
        pipe << msg.to_a.map(&:downcase)
      end
    end
    let(:word) { 'FOO' }
    let(:response) do
      actor.request(word).to_a[0]
    end
    it 'returns response' do
      assert_equal word.downcase, response
    end

    context 'threads' do
      let(:mutex) { actor.instance_variable_get(:@mtx) }
      it 'is thread-safe' do
        expect(mutex).to receive(:synchronize).at_least(:once)
                                              .and_call_original
        response
      end
    end
    context 'with dead actor' do
      before { actor.terminate }
      it 'raises DeadActorError' do
        assert_raises(CZTop::Actor::DeadActorError) do
          response
        end
      end
    end

    context 'with $TERM message' do
      let(:word) { '$TERM' }
      it 'raises' do
        assert_raises(ArgumentError) do
          response
        end
      end
    end

    context 'sndtimeo reached' do
      let(:msg) { CZTop::Message.new('foobar') }
      after { actor.request(msg) }
      it 'retries' do
        expect(msg).to receive(:send_to)
          .with(actor).and_raise(IO::EAGAINWaitWritable).ordered
        expect(msg).to receive(:send_to)
          .with(actor).at_least(:once).and_call_original.ordered
      end
    end
  end

  describe '#terminate' do
    context 'when actor is alive' do
      it 'tells actor to terminate' do
        msg = CZTop::Message.new '$TERM'
        expect(CZTop::Message).to receive(:new).with('$TERM').and_return(msg)
        expect(msg).to receive(:send_to).with(actor).and_call_original
      end

      it 'returns true' do
        assert_equal true, actor.terminate
      end

      it 'waits for handler to terminate' do
        expect(actor.instance_variable_get(:@handler_dead_signal)).to(
          receive(:pop).and_call_original
        )
      end

      context 'with slow handler death' do
        let(:handler_thread) { actor.instance_variable_get(:@handler_thread) }
        it 'waits for heandler thread to terminate' do
          expect(handler_thread).to receive(:join).and_call_original
        end
      end

      context 'sndtimeo reached' do
        let(:term_msg) { CZTop::Message.new('$TERM') }
        before do
          allow(CZTop::Message).to receive(:new).and_return(term_msg)
        end
        it 'retries' do
          expect(term_msg).to receive(:send_to)
            .with(actor).and_raise(IO::EAGAINWaitWritable).ordered
          expect(term_msg).to receive(:send_to)
            .with(actor).at_least(:once).and_call_original.ordered
        end
      end
    end

    context 'with dead actor' do
      before { actor.terminate }

      it 'returns false' do
        assert_equal false, actor.terminate
      end
    end
  end
end
