# frozen_string_literal: true

# Can be used if you want to encode or decode data from one IO to another.
# It'll do so until it hits EOF in the source IO.
class CZTop::Z85::Pipe
  # @param source [IO] where to read data
  # @param sink [IO] where to write data
  # @param strategy [Strategy] algorithm to use (pass the class itself,
  #   not an instance)
  def initialize(source, sink, strategy: Strategy::Parallel)
    @source    = source
    @sink      = sink
    @strategy  = strategy
    @bin_bytes = 0 # processed binary data (non-Z85)
  end

  # @return [Integer] size of chunks read when encoding
  ENCODE_READ_SZ = (32 * (2**10)) # 32 KiB (for full chunks read)

  # @return [Integer] size of chunks read when decoding
  DECODE_READ_SZ = ENCODE_READ_SZ / 4 * 5

  # Encodes data from source and writes Z85 data to sink. This is done
  # until EOF is hit on the source.
  #
  # @return [Integer] number of bytes read (binary data)
  def encode
    @strategy.new(@source, @sink, ENCODE_READ_SZ) do |chunk, prev_chunk|
      @bin_bytes += chunk.bytesize if chunk
      if prev_chunk && chunk
        CZTop::Z85.encode(prev_chunk)
      elsif prev_chunk && chunk.nil? # last chunk
        CZTop::Z85::Padded.encode(prev_chunk)
      elsif prev_chunk.nil? && chunk.nil?
        CZTop::Z85.encode('') # empty input
      else
        '' # very first chunk. don't encode anything yet...
      end
    end.execute
    @bin_bytes
  end


  # Decodes Z85 data from source and writes decoded data to sink. This is
  # done until EOF is hit on the source.
  #
  # @return [Integer] number of bytes written (binary data)
  def decode
    @strategy.new(@source, @sink, DECODE_READ_SZ) do |chunk, prev_chunk|
      if prev_chunk && chunk
        CZTop::Z85.decode(prev_chunk)
      elsif prev_chunk && chunk.nil?
        CZTop::Z85::Padded.decode(prev_chunk)
      elsif prev_chunk.nil? && chunk.nil?
        CZTop::Z85.decode('') # empty input
      else
        '' # very first chunk. don't decode anything yet...
      end
    end.execute
    @bin_bytes
  end


  # @abstract
  # Different encoding/decoding strategies (algorithms).
  #
  # This is mainly just for me to practice the GoF Strategy Pattern.
  class Strategy
    # @param source [IO] the source
    # @param sink [IO] the sink
    # @param read_sz [Integer] chunk size when reading from source
    # @param xcode [Proc] block to encode or decode data
    # @yieldparam chunk [String, nil] current chunk (or +nil+ after the
    #   last one)
    # @yieldparam prev_chunk [String, nil] previous chunk (or +nil+ for
    #   the first time)
    # @yieldreturn [String] encoded/decoded chunk to write to sink
    def initialize(source, sink, read_sz, &xcode)
      @source  = source
      @sink    = sink
      @read_sz = read_sz
      @xcode   = xcode
    end


    # @abstract
    # Runs the algorithm.
    # @raise [void]
    def execute
      raise NotImplementedError
    end


    # A single thread that is either reading input, encoding/decoding, or
    # writing output.
    class Sequential < Strategy
      # Runs the algorithm.
      # @raise [void]
      def execute
        previous_chunk = nil
        while true
          chunk          = @source.read(@read_sz)
          @sink << @xcode.call(chunk, previous_chunk)
          break if chunk.nil?

          previous_chunk = chunk
        end
      end
    end


    # Uses three threads:
    #
    # 1. reads from source
    # 2. encodes/decodes
    # 3. writes to sink
    #
    # This might give a performance increase on truly parallel
    # platforms such as Rubinius and JRuby (and multiple CPU cores).
    #
    class Parallel < Strategy
      # Initializes the 2 sized queues used.
      def initialize(*)
        super
        # @source
        # |
        # V
        @source_queue = SizedQueue.new(20) # limit memory usage
        # |
        # V
        # xcode
        # |
        # V
        @sink_queue   = SizedQueue.new(20) # limit memory usage
        # |
        # V
        # @sink
      end


      # Runs the algorithm.
      # @raise [void]
      def execute
        Thread.new { read }
        Thread.new { xcode }
        write
      end

      private

      # Reads all chunks and pushes them into the source queue. Then
      # pushes a +nil+ into the queue.
      # @return [void]
      def read
        while chunk = @source.read(@read_sz)
          @source_queue << chunk
        end
        @source_queue << nil
      end


      # Pops all chunks from the source queue, encodes or decodes them,
      # and pushes the result into the sink queue. Then pushes a +nil+
      # into the queue.
      # @return [void]
      def xcode
        # Encode all but the last chunk with pure Z85.
        previous_chunk = nil
        while true
          chunk = @source_queue.pop

          # call @xcode for the trailing nil-chunk as well
          @sink_queue << @xcode.call(chunk, previous_chunk)

          break if chunk.nil?

          previous_chunk = chunk
        end
        @sink_queue << nil
      end


      # Pops all chunks from the sink queue and writes them to the sink.
      # @return [void]
      def write
        while chunk = @sink_queue.pop
          @sink << chunk
        end
      end
    end
  end
end
