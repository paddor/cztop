# frozen_string_literal: true

require_relative 'spec_helper'

describe CZTop::Actor do
  include HasFFIDelegateExamples

  it 'has Zsock options' do
    assert_operator CZTop::Actor, :<, CZTop::ZsockOptions
  end

  it 'has send/receive methods' do
    assert_operator CZTop::Actor, :<, CZTop::SendReceiveMethods
  end

  it 'has polymorphic Zsock methods' do
    assert_operator CZTop::Actor, :<, CZTop::PolymorphicZsockMethods
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
    let(:callback_shim) { actor.instance_variable_get(:@callback) }

    describe 'with C callback' do # pointer to C function
      let(:c_function) { CZTop::Beacon::ZBEACON_FPTR }
      let(:actor) { CZTop::Actor.new(c_function) }

      it "doesn't shim it" do
        assert_same c_function, callback_shim
      end
    end

    describe 'with Proc callback' do
      let(:proc_) do
        lambda do |msg, pipe|
          received_messages << msg.to_a
          yielded << [msg, pipe]
        end
      end
      let(:actor) do
        CZTop::Actor.new(proc_)
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

    describe 'with block' do
      # can use default actor
      it 'works' do
        actor << 'FOO'
        actor.terminate
        assert_equal [['FOO']], received_messages
      end
    end
  end

  describe '#shim' do
    describe 'with invalid handler' do
      it 'raises' do
        assert_raises(ArgumentError) { actor.__send__(:shim, 'foo') }
      end
    end

    describe 'with faulty handler' do
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
    describe 'with crashed actor' do
      let(:actor) { CZTop::Actor.new { raise } }
      it 'returns true' do
        assert_operator actor, :crashed?
      end
    end
    describe 'with normally terminated actor' do
      it 'returns false' do
        refute_operator actor, :crashed?
      end
    end
  end

  describe '#exception' do
    before do
      actor << 'foo'
      actor.terminate
    end
    describe 'with crashed actor' do
      let(:error) { RuntimeError.new('foobar') }
      let(:actor) { CZTop::Actor.new { raise error } }
      it 'returns stored exception' do
        assert_same error, actor.exception
      end
    end
    describe 'with alive actor' do
      it 'returns nil' do
        assert_nil actor.exception
      end
    end
    describe 'with normally terminated actor' do
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
      called_with = nil
      ::CZMQ::FFI::Zsock.stub(:send, ->(*args) { called_with = args }) do
        actor.send_picture(picture, *ffi_args)
      end
      assert_equal [ffi_delegate, picture, *ffi_args], called_with
    end

    describe 'with dead actor' do
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
    describe 'when sending $TERM' do
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

    describe 'when interrupted' do
      it 'terminates actor' do
        call_count = 0
        original = actor.method(:next_message)
        actor.stub(:next_message, -> {
          call_count += 1
          raise Interrupt if call_count == 1
          original.call
        }) do
          begin
            actor << 'foo'
          rescue CZTop::Actor::DeadActorError
            # that's okay
          end
        end
        actor.terminate # idempotent
        assert_operator actor, :dead?
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
    describe 'when terminated' do
      it 'returns true' do
        actor.terminate
        assert actor.dead?
      end
    end
    describe 'when not yet terminated' do
      it 'returns false' do
        refute actor.dead?
      end
    end
  end

  describe '#<<' do
    describe 'threads' do
      it 'is thread-safe' do
        # verify the mutex exists and the method works
        mutex = actor.instance_variable_get(:@mtx)
        assert_kind_of Mutex, mutex
        actor << 'foo'
      end
    end

    describe 'with commands' do
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

    describe 'with array' do
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

    describe 'with dead actor' do
      before { actor.terminate }
      it 'raises DeadActorError' do
        assert_raises(CZTop::Actor::DeadActorError) do
          actor << 'FOO'
        end
      end
    end

    describe 'with $TERM' do
      it 'terminates actor' do
        actor << '$TERM'
        assert_operator actor, :dead?
      end
    end

    describe 'sndtimeo reached' do
      it 'retries' do
        msg = CZTop::Message.new('foobar')
        call_count = 0
        original_send_to = msg.method(:send_to)
        msg.stub(:send_to, ->(*args) {
          call_count += 1
          raise IO::EAGAINWaitWritable if call_count == 1
          original_send_to.call(*args)
        }) do
          actor << msg
        end
        assert_operator call_count, :>, 1
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

    describe 'threads' do
      it 'is thread-safe' do
        mutex = actor.instance_variable_get(:@mtx)
        assert_kind_of Mutex, mutex
        actor << 'foo'
        actor.receive
      end
    end

    describe 'with messages available' do
      before do
        actor << 'foo' << 'bar'
      end

      it 'returns messages' do
        assert_equal 'foo', actor.receive[0]
        assert_equal 'bar', actor.receive[0]
      end
    end

    describe 'with dead actor' do
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

    describe 'threads' do
      it 'is thread-safe' do
        mutex = actor.instance_variable_get(:@mtx)
        assert_kind_of Mutex, mutex
        response
      end
    end
    describe 'with dead actor' do
      before { actor.terminate }
      it 'raises DeadActorError' do
        assert_raises(CZTop::Actor::DeadActorError) do
          response
        end
      end
    end

    describe 'with $TERM message' do
      let(:word) { '$TERM' }
      it 'raises' do
        assert_raises(ArgumentError) do
          response
        end
      end
    end

    describe 'sndtimeo reached' do
      it 'retries' do
        msg = CZTop::Message.new('foobar')
        call_count = 0
        original_send_to = msg.method(:send_to)
        msg.stub(:send_to, ->(*args) {
          call_count += 1
          raise IO::EAGAINWaitWritable if call_count == 1
          original_send_to.call(*args)
        }) do
          actor.request(msg)
        end
        assert_operator call_count, :>, 1
      end
    end
  end

  describe '#terminate' do
    describe 'when actor is alive' do
      it 'returns true' do
        assert_equal true, actor.terminate
      end

      it 'waits for handler to terminate' do
        actor.terminate
        assert actor.dead?
      end
    end

    describe 'sndtimeo reached' do
      it 'retries sending $TERM' do
        term_msg = CZTop::Message.new('$TERM')
        call_count = 0
        original_send_to = term_msg.method(:send_to)
        CZTop::Message.stub(:new, ->(*args) {
          if args == ['$TERM']
            term_msg
          else
            CZTop::Message.method(:new).super_method.call(*args)
          end
        }) do
          term_msg.stub(:send_to, ->(*a) {
            call_count += 1
            raise IO::EAGAINWaitWritable if call_count == 1
            original_send_to.call(*a)
          }) do
            actor.terminate
          end
        end
        assert_operator call_count, :>, 1
      end
    end

    describe 'with dead actor' do
      before { actor.terminate }

      it 'returns false' do
        assert_equal false, actor.terminate
      end
    end
  end
end
