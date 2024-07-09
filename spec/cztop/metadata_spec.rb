# frozen_string_literal: true

require_relative 'spec_helper'

describe CZTop::Metadata do
  subject { described_class }
  let(:properties) do
    { foo: 'A', bar: 'B', baz: 'C' }
  end
  let(:serialized) do
    "\x03foo\x00\x00\x00\x01A" \
      "\x03bar\x00\x00\x00\x01B" \
      "\x03baz\x00\x00\x00\x01C"
  end

  describe '.dump' do
    context 'with a single property' do
      let(:name) { :foo }
      let(:value) { 'barbaz' }
      let(:property) { { name => value } }

      let(:encoded_name_length) { [name.to_s.size].pack('C') }
      let(:encoded_value_length) { [value.to_s.size].pack('N') }

      let(:serialized) do
        "#{encoded_name_length}#{name}#{encoded_value_length}#{value}"
      end

      it 'encodes correctly' do
        assert_equal serialized, subject.dump(property)
      end

      context 'with too long property name' do
        let(:name) { ('f' * 256).to_sym }
        it 'raises' do
          assert_raises(ArgumentError) do
            subject.dump(property)
          end
        end
      end

      context 'with too long data' do
        let(:value) { double(to_s: value_string) }
        let(:value_string) { double(bytesize: 2**31) }
        it 'raises' do
          assert_raises(ArgumentError) { subject.dump(property) }
        end
      end
    end

    context 'with multiple properties' do
      it 'encodes correctly' do
        assert_equal serialized, subject.dump(properties)
      end
    end

    context 'with case-insensitively duplicate names' do
      let(:properties) { { foo: 'A', FOO: 'B' } }
      it 'raises' do
        assert_raises(ArgumentError) { subject.dump(properties) }
      end
    end

    context 'with zero-length property names' do
      let(:properties) { { "": 'A', foo: 'B' } }
      it 'raises' do
        assert_raises(ArgumentError) do
          subject.dump(properties)
        end
      end
    end
    context 'with zero-length values' do
      let(:properties) { { a: '' } }
      let(:serialized) { "\x01a\x00\x00\x00\x00" }
      it 'is encodes correctly' do
        assert_equal serialized, subject.dump(properties)
      end
    end
    context 'with invalid property names' do
      let(:bad_names) do
        [
          :'abc/foo',
          '@abc',
          '%',
          '#',
          '!',
          ':name',
          '~',
          '(',
          ')',
          '}',
          '=',
          :'foo;bar'
        ]
      end
      it 'raises' do
        bad_names.each do |name|
          assert_raises(ArgumentError) do
            subject.dump(name => '')
          end
        end
      end
    end
  end

  describe '.load' do
    it 'decodes correctly' do
      deserialized = subject.load(serialized)
      properties.each do |name, value|
        assert_equal value, deserialized[name]
      end
    end
    context 'with zero-length values' do
      let(:serialized) { "\x01x\x00\x00\x00\x00" }
      it 'is decodes correctly' do
        assert_equal '', subject.load(serialized)[:x]
      end
    end

    InvalidData = CZTop::Metadata::InvalidData

    context 'with zero-length property names' do
      let(:serialized) do
        "\x00\x00\x00\x00\x01A" # "" => "A"
      end
      it 'raises' do
        ex = assert_raises(InvalidData) { subject.load(serialized) }
        assert_match(/zero-length property name/, ex.message)
      end
    end
    context 'with case-insensitively duplicate names' do
      let(:serialized) { "\x01x\x00\x00\x00\x00\x01X\x00\x00\x00\x00" }
      it 'raises' do
        ex = assert_raises(InvalidData) { subject.load(serialized) }
        assert_match(/duplicate name/, ex.message)
      end
    end
    context 'with cut-off value length' do
      let(:serialized) { "\x01x\x00\x00\x00" }
      it 'raises' do
        ex = assert_raises(InvalidData) { subject.load(serialized) }
        assert_match(/incomplete length/, ex.message)
      end
    end
    context 'with cut-off value' do
      let(:serialized) { "\x01x\x00\x00\x00\x06fooba" }
      it 'raises' do
        ex = assert_raises(InvalidData) { subject.load(serialized) }
        assert_match(/incomplete value/, ex.message)
      end
    end
  end

  describe '#initialize' do
    context 'with properties' do
      subject { CZTop::Metadata.new(properties) }
      let(:properties_before) { properties.dup }
      before { properties_before }
      it 'remembers properties as-is' do
        assert_same properties, subject.to_h
        assert_equal properties_before, subject.to_h
      end
    end
  end
  describe '#[]' do
    subject { CZTop::Metadata.new(properties) }
    context 'with String property name' do
      it 'returns correct value' do
        assert_equal properties[:foo], subject['fOo']
      end
    end
    context 'with exact-case Symbol property name' do
      it 'returns correct value' do
        assert_equal properties[:foo], subject[:foo]
      end
    end
    context 'with fuzzy-case Symbol property name' do
      it 'returns correct value' do
        assert_equal properties[:foo], subject[:fOo]
      end
    end
    context 'with inexistent property name' do
      it 'returns correct value' do
        assert_nil subject['doesnt-exist']
      end
    end
  end
  describe '#to_h' do
    subject { CZTop::Metadata.new(properties) }
    let(:properties_before) { properties.dup }
    before { properties_before }
    it 'returns properties' do
      assert_equal properties_before, subject.to_h
    end
  end
end
