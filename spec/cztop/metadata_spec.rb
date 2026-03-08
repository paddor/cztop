# frozen_string_literal: true

require_relative 'spec_helper'

describe CZTop::Metadata do
  let(:subject) { CZTop::Metadata }
  let(:properties) do
    { foo: 'A', bar: 'B', baz: 'C' }
  end
  let(:serialized) do
    "\x03foo\x00\x00\x00\x01A" \
      "\x03bar\x00\x00\x00\x01B" \
      "\x03baz\x00\x00\x00\x01C"
  end


  describe '.dump' do
    describe 'with a single property' do
      let(:prop_name) { :foo }
      let(:prop_value) { 'barbaz' }
      let(:property) { { prop_name => prop_value } }

      let(:encoded_name_length) { [prop_name.to_s.size].pack('C') }
      let(:encoded_value_length) { [prop_value.to_s.size].pack('N') }

      let(:serialized) do
        "#{encoded_name_length}#{prop_name}#{encoded_value_length}#{prop_value}"
      end

      it 'encodes correctly' do
        assert_equal serialized, subject.dump(property)
      end


      describe 'with too long property name' do
        let(:prop_name) { ('f' * 256).to_sym }

        it 'raises' do
          assert_raises(ArgumentError) do
            subject.dump(property)
          end
        end
      end


      describe 'with too long data' do
        it 'raises' do
          value_string = Object.new
          value_string.define_singleton_method(:bytesize) { 2**31 }
          value = Object.new
          value.define_singleton_method(:to_s) { value_string }
          assert_raises(ArgumentError) { subject.dump(name => value) }
        end
      end
    end


    describe 'with multiple properties' do
      it 'encodes correctly' do
        assert_equal serialized, subject.dump(properties)
      end
    end


    describe 'with case-insensitively duplicate names' do
      let(:properties) { { foo: 'A', FOO: 'B' } }

      it 'raises' do
        assert_raises(ArgumentError) { subject.dump(properties) }
      end
    end


    describe 'with zero-length property names' do
      let(:properties) { { "": 'A', foo: 'B' } }

      it 'raises' do
        assert_raises(ArgumentError) do
          subject.dump(properties)
        end
      end
    end


    describe 'with zero-length values' do
      let(:properties) { { a: '' } }
      let(:serialized) { "\x01a\x00\x00\x00\x00" }

      it 'is encodes correctly' do
        assert_equal serialized, subject.dump(properties)
      end
    end


    describe 'with invalid property names' do
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


    describe 'with zero-length values' do
      let(:serialized) { "\x01x\x00\x00\x00\x00" }

      it 'is decodes correctly' do
        assert_equal '', subject.load(serialized)[:x]
      end
    end

    InvalidData = CZTop::Metadata::InvalidData


    describe 'with zero-length property names' do
      let(:serialized) do
        "\x00\x00\x00\x00\x01A" # "" => "A"
      end

      it 'raises' do
        ex = assert_raises(InvalidData) { subject.load(serialized) }
        assert_match(/zero-length property name/, ex.message)
      end
    end


    describe 'with case-insensitively duplicate names' do
      let(:serialized) { "\x01x\x00\x00\x00\x00\x01X\x00\x00\x00\x00" }

      it 'raises' do
        ex = assert_raises(InvalidData) { subject.load(serialized) }
        assert_match(/duplicate name/, ex.message)
      end
    end


    describe 'with cut-off value length' do
      let(:serialized) { "\x01x\x00\x00\x00" }

      it 'raises' do
        ex = assert_raises(InvalidData) { subject.load(serialized) }
        assert_match(/incomplete length/, ex.message)
      end
    end


    describe 'with cut-off value' do
      let(:serialized) { "\x01x\x00\x00\x00\x06fooba" }

      it 'raises' do
        ex = assert_raises(InvalidData) { subject.load(serialized) }
        assert_match(/incomplete value/, ex.message)
      end
    end
  end


  describe '#initialize' do
    describe 'with properties' do
      let(:subject) { CZTop::Metadata.new(properties) }
      let(:properties_before) { properties.dup }
      before { properties_before }

      it 'remembers properties as-is' do
        assert_same properties, subject.to_h
        assert_equal properties_before, subject.to_h
      end
    end
  end


  describe '#[]' do
    let(:subject) { CZTop::Metadata.new(properties) }


    describe 'with String property name' do
      it 'returns correct value' do
        assert_equal properties[:foo], subject['fOo']
      end
    end


    describe 'with exact-case Symbol property name' do
      it 'returns correct value' do
        assert_equal properties[:foo], subject[:foo]
      end
    end


    describe 'with fuzzy-case Symbol property name' do
      it 'returns correct value' do
        assert_equal properties[:foo], subject[:fOo]
      end
    end


    describe 'with inexistent property name' do
      it 'returns correct value' do
        assert_nil subject['doesnt-exist']
      end
    end
  end


  describe '#to_h' do
    let(:subject) { CZTop::Metadata.new(properties) }
    let(:properties_before) { properties.dup }
    before { properties_before }

    it 'returns properties' do
      assert_equal properties_before, subject.to_h
    end
  end
end
