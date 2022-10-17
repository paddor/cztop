# frozen_string_literal: true

require_relative '../spec_helper'

describe 'CZTop::Beacon::ZBEACON_FPTR' do
  it 'points to a dynamic library symbol' do
    assert_kind_of FFI::DynamicLibrary::Symbol, CZTop::Beacon::ZBEACON_FPTR
  end
end

describe CZTop::Beacon do
  subject { CZTop::Beacon.new }
  let(:actor) { subject.actor }

  after do
    subject.terminate
  end

  it 'initializes and terminates' do
    subject
  end

  describe '#verbose!' do
    before do
      expect(actor).to receive(:<<).with('VERBOSE').and_call_original
    end
    it 'sends correct message to actor' do
      subject.verbose!
    end
  end

  describe '#configure' do
    let(:port) { 9999 }
    let(:hostname) { 'example.com' }
    let(:ptr) { FFI::MemoryPointer.from_string(hostname) }
    context 'with support for UDP broadcasts' do
      before do
        expect(actor).to receive(:send_picture)
          .with(kind_of(String), :string, 'CONFIGURE', :int, port)
        expect(CZMQ::FFI::Zstr).to receive(:recv).with(actor)
                                                 .and_return(ptr)
      end
      it 'sends correct message to actor' do
        assert_equal hostname, subject.configure(port)
      end
    end
    context 'no support for UDP broadcasts' do
      let(:hostname) { '' }
      let(:ptr) { FFI::MemoryPointer.from_string(hostname) }
      before do
        allow(actor).to receive(:send_picture)
        expect(CZMQ::FFI::Zstr).to receive(:recv).with(actor).and_return(ptr)
      end
      it 'raises' do
        assert_raises(NotImplementedError) do
          subject.configure(port)
        end
      end
    end
    context 'when interrupted' do
      let(:nullptr) { ::FFI::Pointer::NULL } # represents failure
      before do
        expect(CZMQ::FFI::Zstr).to receive(:recv).with(actor)
                                                 .and_return(nullptr)
        expect(CZMQ::FFI::Errors).to receive(:errno)
          .and_return(Errno::EINTR::Errno)
      end
      it 'raises' do
        assert_raises(Interrupt) do
          subject.configure(port)
        end
      end
    end
  end
  describe '#publish' do
    let(:data) { 'foobar data' }
    let(:data_size) { data.bytesize }
    let(:interval) { 1000 }
    context 'with data' do
      before do
        expect(actor).to receive(:send_picture)
          .with(kind_of(String), :string, 'PUBLISH', :string, data,
                :int, data_size, :int, interval)
      end
      it 'sends correct message to actor' do
        subject.publish(data, interval)
      end
    end
    context 'with data too long' do
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
      expect(actor).to receive(:<<).with('SILENCE')
      subject.silence
    end
  end
  describe '#subscribe' do
    let(:filter) { 'foo filter' }
    let(:filter_size) { filter.bytesize }
    before do
      expect(actor).to receive(:send_picture)
        .with(kind_of(String), :string, 'SUBSCRIBE', :string, filter, :int,
              filter_size)
    end
    it 'sends correct message to actor' do
      subject.subscribe(filter)
    end
  end
  describe '#listen' do
    before do
      expect(actor).to receive(:send_picture)
        .with(kind_of(String), :string, 'SUBSCRIBE', :string, nil, :int, 0)
    end
    it 'sends correct message to actor' do
      subject.listen
    end
  end
  describe '#unsubscribe' do
    before do
      expect(actor).to receive(:<<).with('UNSUBSCRIBE')
    end
    it 'sends correct message to actor' do
      subject.unsubscribe
    end
  end
  describe '#receive' do
    let(:msg) { double('message') }
    before do
      expect(actor).to receive(:receive).and_return(msg)
    end
    it 'receives a message from actor' do
      assert_equal msg, subject.receive
    end
  end
end
