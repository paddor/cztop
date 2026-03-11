# frozen_string_literal: true

require_relative 'test_helper'

describe CZTop::ZsockOptions do
  include ZMQHelper

  i = 0
  let(:endpoint) { "inproc://zsock_options_#{i += 1}" }
  let(:socket)   { CZTop::Socket::REQ.new(endpoint) }


  describe '#options' do
    it 'returns options accessor' do
      assert_kind_of CZTop::ZsockOptions::OptionsAccessor, socket.options
    end

    it 'memoizes the options accessor' do
      assert_same socket.options, socket.options
    end

    it "changes the correct socket's options" do
      assert_same socket, socket.options.zocket
    end
  end


  describe 'event-based methods' do
    describe '#readable?' do
      describe 'with read event set' do
        it 'returns true' do
          socket.options.stub(:events, CZTop::ZsockOptions::POLLIN) do
            assert_operator socket, :readable?
          end
        end
      end


      describe 'with read event unset' do
        it 'returns false' do
          socket.options.stub(:events, 0) do
            refute_operator socket, :readable?
          end
        end
      end
    end


    describe '#writable?' do
      describe 'with write event set' do
        it 'returns true' do
          socket.options.stub(:events, CZTop::ZsockOptions::POLLOUT) do
            assert_operator socket, :writable?
          end
        end
      end


      describe 'with write event unset' do
        it 'returns false' do
          socket.options.stub(:events, 0) do
            refute_operator socket, :writable?
          end
        end
      end
    end
  end


  describe '#fd' do
    it 'returns socket FD' do
      assert_equal socket.options.fd, socket.fd
    end
  end


  describe '#to_io' do
    it 'returns IO' do
      assert_kind_of IO, socket.to_io
      assert_equal socket.options.fd, socket.to_io.fileno
    end

    it 'will not autoclose' do
      refute_operator socket.to_io, :autoclose?
    end
  end


  describe CZTop::ZsockOptions::OptionsAccessor do
    describe '#sndhwm' do
      describe 'when getting current value' do
        it 'returns value' do
          assert_kind_of Integer, socket.options.sndhwm
        end
      end


      describe 'when setting new value' do
        let(:new_value) { 99 }
        before { socket.options.sndhwm = new_value }

        it 'sets new value' do
          assert_equal new_value, socket.options.sndhwm
        end
      end
    end


    describe '#rcvhwm' do
      describe 'when getting current value' do
        it 'returns value' do
          assert_kind_of Integer, socket.options.rcvhwm
        end
      end


      describe 'when setting new value' do
        let(:new_value) { 99 }
        before { socket.options.rcvhwm = new_value }

        it 'sets new value' do
          assert_equal new_value, socket.options.rcvhwm
        end
      end
    end


    describe '#sndtimeo' do
      it 'sets and gets send timeout' do
        assert_equal(-1, socket.options.sndtimeo)

        socket.options.sndtimeo = 7
        assert_equal 7, socket.options.sndtimeo

        socket.options.sndtimeo = 0
        assert_equal 0, socket.options.sndtimeo
      end
    end


    describe '#rcvtimeo' do
      it 'sets and gets receive timeout' do
        assert_equal(-1, socket.options.rcvtimeo)
        socket.options.rcvtimeo = 7
        assert_equal 7, socket.options.rcvtimeo
      end
    end


    describe '#router_mandatory=' do
      let(:router) { CZTop::Socket::ROUTER.new(endpoint) }

      it 'can set the flag' do
        called_with = nil
        CZMQ::FFI::Zsock.stub(:set_router_mandatory, ->(*args) { called_with = args }) do
          router.options.router_mandatory = true
        end
        assert_equal [router, 1], called_with
      end

      it 'can unset the flag' do
        called_with = nil
        CZMQ::FFI::Zsock.stub(:set_router_mandatory, ->(*args) { called_with = args }) do
          router.options.router_mandatory = false
        end
        assert_equal [router, 0], called_with
      end
    end


    describe '#router_mandatory?' do
      let(:router) { CZTop::Socket::ROUTER.new(endpoint) }

      it 'gets the flag' do
        refute_operator router.options, :router_mandatory?
        router.options.router_mandatory = true
        assert_operator router.options, :router_mandatory?
        router.options.router_mandatory = false
        refute_operator router.options, :router_mandatory?
      end
    end


    describe '#identity' do
      describe 'with no identity set' do
        it 'returns empty string' do
          assert_equal '', socket.options.identity
        end
      end


      describe 'with identity set' do
        let(:identity) { 'foobar' }
        before { socket.options.identity = identity }

        it 'returns identity' do
          assert_equal identity, socket.options.identity
        end
      end
    end


    describe '#identity=' do
      describe 'with zero-length identity' do
        it 'raises' do
          assert_raises(ArgumentError) { socket.options.identity = '' }
        end
      end


      describe 'with invalid identity' do
        # NOTE: leading null byte is reserved for ZMQ
        it 'raises' do
          assert_raises(ArgumentError) { socket.options.identity = "\x00foobar" }
        end
      end


      describe 'with too long identity' do
        # NOTE: identities are 255 bytes maximum
        it 'raises' do
          assert_raises(ArgumentError) { socket.options.identity = 'x' * 256 }
        end
      end
    end


    describe '#tos' do
      describe 'with no TOS' do
        it 'returns zero' do
          assert_equal 0, socket.options.tos
        end
      end


      describe 'with TOS set' do
        let(:tos) { 5 }
        before { socket.options.tos = tos }

        it 'returns TOS' do
          assert_equal tos, socket.options.tos
        end
      end


      describe 'with invalid TOS' do
        it 'raises' do
          assert_raises(ArgumentError) { socket.options.tos = -5 }
        end
      end


      describe 'when resetting to zero' do
        before { socket.options.tos = 10 }

        it "doesn't raise" do
          socket.options.tos = 0
        end
      end
    end


    describe '#linger' do
      describe 'with no LINGER' do
        it 'returns default' do
          assert_equal 0, socket.options.linger # ZMQ docs say 30_000, but they're wrong
        end
      end


      describe 'with LINGER set' do
        let(:linger) { 500 }
        before { socket.options.linger = linger }

        it 'returns LINGER' do
          assert_equal linger, socket.options.linger
        end
      end
    end


    describe '#ipv6=' do
      it 'can enable IPv6' do
        called_with = nil
        CZMQ::FFI::Zsock.stub(:set_ipv6, ->(*args) { called_with = args }) do
          socket.options.ipv6 = true
        end
        assert_equal [socket, 1], called_with
      end

      it 'can disable IPv6' do
        called_with = nil
        CZMQ::FFI::Zsock.stub(:set_ipv6, ->(*args) { called_with = args }) do
          socket.options.ipv6 = false
        end
        assert_equal [socket, 0], called_with
      end
    end


    describe '#ipv6?' do
      describe 'with default setting' do
        it 'returns false' do
          refute_operator socket.options, :ipv6?
        end
      end


      describe 'with ipv6 enabled' do
        before { socket.options.ipv6 = true }

        it 'returns true' do
          assert_operator socket.options, :ipv6?
        end
      end


      describe 'with ipv6 disabled' do
        before { socket.options.ipv6 = false }

        it 'returns false' do
          refute_operator socket.options, :ipv6?
        end
      end
    end


    describe '#[]' do
      describe 'with vague option name' do
        let(:identity) { 'foobar' }
        before do
          socket.options.identity = identity
        end

        it 'gets option' do
          assert_equal identity, socket.options[:IDENTITY]
          assert_equal identity, socket.options['IDENTITY']
          assert_equal socket.options.tos, socket.options[:ToS]
        end
      end


      describe 'with plain wrong option name' do
        it 'raises' do
          assert_raises(NoMethodError) { socket.options[:foo] }
          assert_raises(NoMethodError) { socket.options[5] }
          assert_raises(NoMethodError) { socket.options['!!'] }
        end
      end
    end


    describe '#[]=' do
      let(:identity) { 'foobar' }
      let(:tos)      { 5 }
      before do
        socket.options[:IDENTITY] = identity
        socket.options[:ToS] = tos
      end


      describe 'with vague option name' do
        it 'sets option' do
          assert_equal identity, socket.options.identity
          assert_equal tos, socket.options.tos
        end
      end


      describe 'with plain wrong option name' do
        it 'raises' do
          assert_raises(NoMethodError) { socket.options[:foo] = 5 }
          assert_raises(NoMethodError) { socket.options[5] = 'foo' }
          assert_raises(NoMethodError) { socket.options['!!'] = :bar }
        end
      end
    end


    describe '#fd' do
      it 'FD is of correct type' do
        fd_type = FFI::Platform.unix? ? Integer : FFI::Pointer
        assert_kind_of(fd_type, socket.options.fd)
      end
    end


    describe '#reconnect_ivl' do
      describe 'with no RECONNECT_IVL' do
        it 'returns default' do
          assert_equal 100, socket.options.reconnect_ivl
        end
      end


      describe 'with RECONNECT_IVL set' do
        let(:reconnect_ivl) { 500 }
        before { socket.options.reconnect_ivl = reconnect_ivl }

        it 'returns RECONNECT_IVL' do
          assert_equal reconnect_ivl, socket.options.reconnect_ivl
        end
      end
    end


    describe '#events' do
      let(:writer) { CZTop::Socket::PUSH.new(endpoint) }
      let(:reader) { CZTop::Socket::PULL.new(endpoint) }


      describe 'with readable socket' do
        before { writer << 'foo' }

        it 'is readable' do
          assert (reader.options.events & CZTop::ZsockOptions::POLLIN) > 0,
                 'should be readable'
        end
      end


      describe 'with non-readable socket' do
        it 'is not readable' do
          assert (reader.options.events & CZTop::ZsockOptions::POLLIN) == 0,
                 'should not be readable'
        end
      end


      describe 'with writable socket' do
        it 'is writable' do
          assert (writer.options.events & CZTop::ZsockOptions::POLLOUT) > 0,
                 'should be writable'
        end
      end


      describe 'with non-writable socket' do
        let(:full_writer) do
          sock = CZTop::Socket::PUSH.new
          sock.options.sndhwm = 1 # set SNDHWM option before connecting
          sock.connect(endpoint)
          sock << 'is now full'
          sock
        end

        it 'is not writable' do
          assert (full_writer.options.events & CZTop::ZsockOptions::POLLOUT) == 0,
                 'should not be writable'
        end
      end
    end
  end
end
