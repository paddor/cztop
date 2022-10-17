# frozen_string_literal: true

require_relative '../spec_helper'

describe CZTop::Z85::Pipe do
  Z85 = CZTop::Z85
  ENC_SZ = CZTop::Z85::Pipe::ENCODE_READ_SZ

  let(:pipe) { Z85::Pipe.new(source, sink) }
  let(:source) { StringIO.new(input) }
  let(:sink) { StringIO.new(+'') }
  let(:output_len) { output.bytesize }
  let(:input_len) { input.bytesize }

  context 'when encoding' do
    let(:output) { pipe.encode; sink.string }
    context 'with zero-length input' do
      let(:input) { '' }
      it 'produces zero-length output' do
        assert_equal input, output
      end
    end
    context 'with chunk-sized input' do
      let(:input) { '.' * ENC_SZ }
      it 'works correctly' do
        correct = Z85.encode('.' * ENC_SZ + ("\x04" * 4))
        assert_equal correct, output
      end
      it 'produces output of correct length' do
        assert_equal (ENC_SZ + 4) / 4 * 5, output_len
      end
      context 'times two' do
        let(:input) { '.' * 2 * ENC_SZ }
        it 'works correctly' do
          correct = Z85.encode('.' * ENC_SZ * 2 + ("\x04" * 4))
          assert_equal correct, output
        end
      end
    end
    context 'with long input' do
      let(:input) { '.' * (ENC_SZ * 1.1).to_i } # >chunk
      let(:nfull_chunks) { input_len / ENC_SZ } # number of full chunks
      let(:full_chunks_len) do # total length of all full (non-padded) chunks
        Z85.encode('.' * ENC_SZ).bytesize * nfull_chunks
      end
      let(:last_chunk_len) do # encoded length
        len = (input_len % ENC_SZ)
        len += 4 - len % 4
        len / 4 * 5
      end
      let(:correct_length) do # encoded length
        full_chunks_len + last_chunk_len
      end
      it 'produces output of correct length' do
        assert_equal correct_length, output_len
      end
      it 'produces correct output' do
        beginning = input.byteslice(0, ENC_SZ)
        rest = input.byteslice(ENC_SZ..-1)
        padding_bytes = 4 - rest.bytesize % 4
        padding_bytes = 4 if padding_bytes.zero?
        rest << ([padding_bytes].pack('C') * padding_bytes)
        correct = Z85.encode(beginning + rest)
        assert_equal correct, output
      end
    end
  end
  context 'when decoding' do
    let(:output) { pipe.decode; sink.string }
    let(:input) do
      source = StringIO.new(unencoded_input)
      sink = StringIO.new
      Z85::Pipe.new(source, sink).encode
      sink.string
    end
    context 'with zero-length input' do
      let(:input) { '' }
      it 'output is also zero-length' do
        assert_equal input, output
      end
    end
    context 'with chunks-sized input' do
      let(:unencoded_input) { '.' * ENC_SZ }
      it 'works correctly' do
        assert_equal unencoded_input, output
      end
      context 'times two' do
        let(:unencoded_input) { '.' * 2 * ENC_SZ }
        it 'works correctly' do
          assert_equal unencoded_input, output
        end
      end
    end
    context 'with long input' do
      # a bit more than a full chunk size
      let(:unencoded_input) { '.' * (ENC_SZ * 1.1).to_i } # >chunk

      it 'decodes to original input' do
        assert_equal unencoded_input.bytesize, output_len
        assert_equal unencoded_input, output
      end
    end
  end
end

describe CZTop::Z85::Pipe::Strategy do
  Sequential = CZTop::Z85::Pipe::Strategy::Sequential
  Parallel = CZTop::Z85::Pipe::Strategy::Parallel

  let(:input) { 'foobar ' * 100 }
  let(:source) { StringIO.new(input) }
  let(:sink) { StringIO.new }
  let(:roundtrip_output) do
    CZTop::Z85::Pipe.new(source, sink, strategy: strategy_class).encode
    new_source = StringIO.new(sink.string)
    new_sink = StringIO.new
    CZTop::Z85::Pipe.new(new_source, new_sink, strategy: strategy_class).decode
    new_sink.string
  end

  let(:strategy) do
    strategy_class.new(source, sink, read_sz) do |chunk, prev_chunk|
      calls << [prev_chunk, chunk]
    end
  end
  let(:read_sz) { 4 }
  let(:calls) { [] }

  context Sequential do
    let(:strategy_class) { Sequential }
    context 'when used' do
      it 'roundtrips' do
        assert_equal input, roundtrip_output
      end
    end

    describe '#execute' do
      context 'with even input' do
        let(:input) { 'abcdefgh' } # multiple of chunk
        before { strategy.execute }
        it 'passes chunks one by one, and trailing nil' do
          assert_equal [
            [nil, 'abcd'],
            ['abcd', 'efgh'],
            ['efgh', nil]
          ], calls
        end
      end
      context 'with uneven input' do
        let(:input) { 'abcdef' }
        before { strategy.execute }
        it 'passes chunks one by one, and trailing nil' do
          assert_equal [
            [nil, 'abcd'],
            ['abcd', 'ef'],
            ['ef', nil]
          ], calls
        end
      end
    end
  end
  context Parallel do
    let(:strategy_class) { Parallel }
    context 'when used' do
      it 'roundtrips' do
        assert_equal input, roundtrip_output
      end
    end
    describe '#execute' do
      context 'with even input' do
        let(:input) { 'abcdefgh' } # multiple of chunk
        before { strategy.execute }
        it 'passes chunks one by one, and trailing nil' do
          assert_equal [
            [nil, 'abcd'],
            ['abcd', 'efgh'],
            ['efgh', nil]
          ], calls
        end
      end
      context 'with uneven input' do
        let(:input) { 'abcdef' }
        before { strategy.execute }
        it 'passes chunks one by one, and trailing nil' do
          assert_equal [
            [nil, 'abcd'],
            ['abcd', 'ef'],
            ['ef', nil]
          ], calls
        end
      end
    end
  end
end
