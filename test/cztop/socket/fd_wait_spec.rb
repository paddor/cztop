# frozen_string_literal: true

require_relative '../spec_helper'

describe CZTop::Socket::FdWait do
  require 'async'

  describe '#wait_for_fd_signal' do
    let(:req) { CZTop::Socket::REQ.new }

    it 'waits for readability on ZMQ FD' do
      waited = false
      io = Object.new
      io.define_singleton_method(:wait_readable) { |*| waited = true; nil }
      req.stub(:to_io, io) do
        req.wait_for_fd_signal
      end
      assert waited
    end

    it 'memoizes IO object' do
      call_count = 0
      io = Object.new
      io.define_singleton_method(:wait_readable) { |*| nil }
      req.stub(:to_io, ->(*) { call_count += 1; io }) do
        req.wait_for_fd_signal
        req.wait_for_fd_signal
        req.wait_for_fd_signal
      end
      assert_equal 1, call_count
    end


    describe 'with small timeout' do
      it 'uses that timeout' do
        received_timeout = nil
        io = Object.new
        io.define_singleton_method(:wait_readable) { |t = nil| received_timeout = t; nil }
        req.stub(:to_io, io) do
          req.wait_for_fd_signal 0.05
        end
        assert_equal 0.05, received_timeout
      end
    end


    describe 'with large timeout' do
      it 'uses reasonably small timeout' do
        received_timeout = nil
        io = Object.new
        io.define_singleton_method(:wait_readable) { |t = nil| received_timeout = t; nil }
        req.stub(:to_io, io) do
          req.wait_for_fd_signal 10
        end
        assert received_timeout < 1.0
      end
    end


    describe 'with no timeout' do
      it 'still uses a timeout' do
        received_timeout = nil
        io = Object.new
        io.define_singleton_method(:wait_readable) { |t = nil| received_timeout = t; nil }
        req.stub(:to_io, io) do
          req.wait_for_fd_signal
        end
        assert_kind_of Numeric, received_timeout
      end
    end
  end if IO.method_defined?(:wait_readable)
end
