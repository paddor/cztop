# frozen_string_literal: true

require_relative '../spec_helper'

describe 'CZTop::Beacon::ZBEACON_FPTR' do
  it 'points to a dynamic library symbol' do
    assert_kind_of FFI::DynamicLibrary::Symbol, CZTop::Beacon::ZBEACON_FPTR
  end
end

describe CZTop::Beacon do
  let(:subject) { CZTop::Beacon.new }
  let(:actor) { subject.actor }

  after do
    subject.terminate
  end

  it 'initializes and terminates' do
    subject
  end

  describe '#verbose!' do
    it 'sends correct message to actor' do
      sent = nil
      original_send = actor.method(:<<)
      actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
        subject.verbose!
      end
      assert_equal 'VERBOSE', sent
    end
  end

  describe '#configure' do
    let(:port) { 9999 }
    let(:hostname) { 'example.com' }
    let(:ptr) { FFI::MemoryPointer.from_string(hostname) }
    describe 'with support for UDP broadcasts' do
      it 'sends correct message to actor' do
        sent_args = nil
        actor.stub(:send_picture, ->(*args) { sent_args = args }) do
          CZMQ::FFI::Zstr.stub(:recv, ->(_) { ptr }) do
            assert_equal hostname, subject.configure(port)
          end
        end
        assert_kind_of String, sent_args[0]
        assert_equal [:string, 'CONFIGURE', :int, port], sent_args[1..]
      end
    end
    describe 'no support for UDP broadcasts' do
      let(:hostname) { '' }
      let(:ptr) { FFI::MemoryPointer.from_string(hostname) }
      it 'raises' do
        actor.stub(:send_picture, ->(*) {}) do
          CZMQ::FFI::Zstr.stub(:recv, ->(_) { ptr }) do
            assert_raises(NotImplementedError) do
              subject.configure(port)
            end
          end
        end
      end
    end
    describe 'when interrupted' do
      let(:nullptr) { ::FFI::Pointer::NULL } # represents failure
      it 'raises' do
        actor.stub(:send_picture, ->(*) {}) do
          CZMQ::FFI::Zstr.stub(:recv, ->(_) { nullptr }) do
            CZMQ::FFI::Errors.stub(:errno, Errno::EINTR::Errno) do
              assert_raises(Interrupt) do
                subject.configure(port)
              end
            end
          end
        end
      end
    end
  end

  describe '#publish' do
    let(:data) { 'foobar data' }
    let(:data_size) { data.bytesize }
    let(:interval) { 1000 }
    describe 'with data' do
      it 'sends correct message to actor' do
        sent_args = nil
        actor.stub(:send_picture, ->(*args) { sent_args = args }) do
          subject.publish(data, interval)
        end
        assert_kind_of String, sent_args[0]
        assert_equal [:string, 'PUBLISH', :string, data, :int, data_size, :int, interval],
                     sent_args[1..]
      end
    end
    describe 'with data too long' do
      let(:data) { 'x' * 256 } # max = 255 bytes
      it 'raises' do
        assert_raises(ArgumentError) do
          subject.publish(data, interval)
        end
      end
    end
  end

  describe '#silence' do
    it 'sends correct message to actor' do
      sent = nil
      actor.stub(:<<, ->(*args) { sent = args[0] }) do
        subject.silence
      end
      assert_equal 'SILENCE', sent
    end
  end

  describe '#subscribe' do
    let(:filter) { 'foo filter' }
    let(:filter_size) { filter.bytesize }
    it 'sends correct message to actor' do
      sent_args = nil
      actor.stub(:send_picture, ->(*args) { sent_args = args }) do
        subject.subscribe(filter)
      end
      assert_kind_of String, sent_args[0]
      assert_equal [:string, 'SUBSCRIBE', :string, filter, :int, filter_size],
                   sent_args[1..]
    end
  end

  describe '#listen' do
    it 'sends correct message to actor' do
      sent_args = nil
      actor.stub(:send_picture, ->(*args) { sent_args = args }) do
        subject.listen
      end
      assert_kind_of String, sent_args[0]
      assert_equal [:string, 'SUBSCRIBE', :string, nil, :int, 0], sent_args[1..]
    end
  end

  describe '#unsubscribe' do
    it 'sends correct message to actor' do
      sent = nil
      actor.stub(:<<, ->(*args) { sent = args[0] }) do
        subject.unsubscribe
      end
      assert_equal 'UNSUBSCRIBE', sent
    end
  end

  describe '#receive' do
    it 'receives a message from actor' do
      fake_msg = Object.new
      actor.stub(:receive, fake_msg) do
        assert_equal fake_msg, subject.receive
      end
    end
  end
end
