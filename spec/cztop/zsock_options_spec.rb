# frozen_string_literal: true

require_relative 'spec_helper'

describe CZTop::ZsockOptions do
  i = 0
  let(:endpoint) { "inproc://zsock_options_#{i += 1}" }
  let(:socket) { CZTop::Socket::REQ.new(endpoint) }

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
    before do
      expect(socket.options).to receive(:events).and_return(events)
    end
    describe '#readable?' do
      context 'with read event set' do
        let(:events) { CZTop::Poller::ZMQ::POLLIN }
        it 'returns true' do
          assert_operator socket, :readable?
        end
      end
      context 'with read event unset' do
        let(:events) { 0 }
        it 'returns false' do
          refute_operator socket, :readable?
        end
      end
    end

    describe '#writable?' do
      context 'with write event set' do
        let(:events) { CZTop::Poller::ZMQ::POLLOUT }
        it 'returns true' do
          assert_operator socket, :writable?
        end
      end
      context 'with write event unset' do
        let(:events) { 0 }
        it 'returns false' do
          refute_operator socket, :writable?
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
      context 'when getting current value' do
        it 'returns value' do
          assert_kind_of Integer, socket.options.sndhwm
        end
      end
      context 'when setting new value' do
        let(:new_value) { 99 }
        before { socket.options.sndhwm = new_value }
        it 'sets new value' do
          assert_equal new_value, socket.options.sndhwm
        end
      end
    end
    describe '#rcvhwm' do
      context 'when getting current value' do
        it 'returns value' do
          assert_kind_of Integer, socket.options.rcvhwm
        end
      end
      context 'when setting new value' do
        let(:new_value) { 99 }
        before { socket.options.rcvhwm = new_value }
        it 'sets new value' do
          assert_equal new_value, socket.options.rcvhwm
        end
      end
    end
    describe '#CURVE_server?', if: ::CZMQ::FFI::Zsys.has_curve do
      it 'sets and gets CURVE server flag' do
        refute socket.options.CURVE_server?
        socket.options.CURVE_server = true
        assert socket.options.CURVE_server?
        socket.options.CURVE_server = false
        refute socket.options.CURVE_server?
      end

      it 'is mutually exclusive with PLAIN' do
        socket.options.CURVE_server = true
        socket.options.PLAIN_server = true
        refute_operator socket.options, :CURVE_server?
      end
    end

    describe '#CURVE_serverkey', if: ::CZMQ::FFI::Zsys.has_curve do
      context 'with key not set' do
        it 'returns nil' do
          assert_nil socket.options.CURVE_serverkey
        end
      end
      context 'with valid key' do
        let(:cert) { CZTop::Certificate.new }
        let(:key_bin) { cert.public_key(format: :binary) }
        let(:key_z85) { cert.public_key(format: :z85) }
        context 'as binary' do
          When { socket.options.CURVE_serverkey = key_bin }
          Then { key_z85 == socket.options.CURVE_serverkey }
        end
        context 'as Z85' do
          When { socket.options.CURVE_serverkey = key_z85 }
          Then { key_z85 == socket.options.CURVE_serverkey }
        end
      end
      context 'with invalid key' do
        it 'raises' do
          assert_raises(ArgumentError) { socket.options.CURVE_serverkey = 'foo' }
          assert_raises { socket.options.CURVE_serverkey = nil }
        end
      end
    end

    describe '#CURVE_secretkey', if: ::CZMQ::FFI::Zsys.has_curve do
      context 'with key not set' do
        Then { socket.options.CURVE_secretkey.nil? }
      end
      context 'with valid key' do
        let(:cert) { CZTop::Certificate.new }
        let(:key_bin) { cert.secret_key(format: :binary) }
        let(:key_z85) { cert.secret_key(format: :z85) }
        When { cert.apply(socket) }
        Then { key_z85 == socket.options.CURVE_secretkey }
      end
      context 'with only CURVE mechanism enabled but no key set' do
        When { socket.options.CURVE_server = true } # just enable CURVE
        Then { socket.options.CURVE_secretkey.is_a? String }
        And { !socket.options.CURVE_secretkey.empty? }
      end
    end

    describe '#mechanism' do
      context 'with no security' do
        it 'returns :NULL' do
          assert_equal :NULL, socket.options.mechanism
        end
      end
      context 'with PLAIN security' do
        When { socket.options.PLAIN_server = true }
        Then { :PLAIN == socket.options.mechanism }
      end
      context 'with CURVE security', if: ::CZMQ::FFI::Zsys.has_curve do
        When { socket.options.CURVE_server = true }
        Then { :CURVE == socket.options.mechanism }
      end
      #      context "with GSSAPI security" do
      #        it "returns :GSSAPI" # FIXME: see "GSSAPI" branch
      #      end
      context 'with unknown security mechanism' do
        before do
          expect(CZMQ::FFI::Zsock).to receive(:mechanism)
            .with(socket).and_return(99)
        end
        it 'raises' do
          assert_raises { socket.options.mechanism }
        end
      end
    end

    describe '#zap_domain' do
      context 'with no ZAP domain set' do
        Then { '' == socket.options.zap_domain }
      end
      context 'with valid ZAP domain' do
        Given(:domain) { 'foobar' }
        When { socket.options.zap_domain = domain }
        Then { domain == socket.options.zap_domain }
      end
      context 'with too long ZAP domain' do
        Given(:domain) { 'o' * 255 }
        When(:result) { socket.options.zap_domain = domain }
        Then { result == Failure(ArgumentError) }
      end
    end

    describe '#PLAIN_server' do
      it 'sets and gets PLAIN server flag' do
        refute socket.options.PLAIN_server?
        socket.options.PLAIN_server = true
        assert socket.options.PLAIN_server?
        socket.options.PLAIN_server = false
        refute socket.options.PLAIN_server?
      end

      it 'is mutually exclusive with CURVE', if: ::CZMQ::FFI::Zsys.has_curve do
        socket.options.PLAIN_server = true
        socket.options.CURVE_server = true
        refute_operator socket.options, :PLAIN_server?
      end
    end
    describe '#PLAIN_username' do
      context 'with no username set' do
        Then { socket.options.PLAIN_username.nil? }
      end
      context 'setting and getting' do
        Given(:username) { 'foo' }
        When { socket.options.PLAIN_username = username }
        Then { username == socket.options.PLAIN_username }
      end
    end
    describe '#PLAIN_password' do
      context 'with not PLAIN mechanism' do
        Then { socket.options.PLAIN_password.nil? }
      end
      context 'with password set' do
        Given(:password) { 'secret' }
        When { socket.options.PLAIN_password = password }
        Then { socket.options.PLAIN_password == password }
      end
      context 'with only username set' do
        When { socket.options.PLAIN_username = 'foo' }
        Then { '' == socket.options.PLAIN_password }
      end
      context 'setting and getting' do
        Given(:password) { 'foo' }
        When { socket.options.PLAIN_password = password }
        When { password == socket.options.PLAIN_password }
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
        expect(CZMQ::FFI::Zsock).to receive(:set_router_mandatory).with(router, 1)
        router.options.router_mandatory = true
      end
      it 'can unset the flag' do
        expect(CZMQ::FFI::Zsock).to receive(:set_router_mandatory).with(router, 0)
        router.options.router_mandatory = false
      end
      context 'with flag set and message unroutable' do
        before { router.options.router_mandatory = true }
        let(:identity) { 'receiver identity' }
        let(:content) { 'foobar' }
        let(:msg) { [identity, '', content] }
        it 'raises' do
          assert_raises(SocketError) { router << msg }
        end
      end
    end

    describe '#identity' do
      context 'with no identity set' do
        it 'returns empty string' do
          assert_equal '', socket.options.identity
        end
      end
      context 'with identity set' do
        let(:identity) { 'foobar' }
        before { socket.options.identity = identity }
        it 'returns identity' do
          assert_equal identity, socket.options.identity
        end
      end
    end

    describe '#identity=' do
      context 'with zero-length identity' do
        let(:identity) { '' }
        it 'raises' do
          assert_raises(ArgumentError) { socket.options.identity = identity }
        end
      end
      context 'with invalid identity' do
        # NOTE: leading null byte is reserved for ZMQ
        let(:identity) { "\x00foobar" }
        it 'raises' do
          assert_raises(ArgumentError) { socket.options.identity = identity }
        end
      end
      context 'with too long identity' do
        # NOTE: identities are 255 bytes maximum
        let(:identity) { 'x' * 256 }
        it 'raises' do
          assert_raises(ArgumentError) { socket.options.identity = identity }
        end
      end
    end

    describe '#tos' do
      context 'with no TOS' do
        it 'returns zero' do
          assert_equal 0, socket.options.tos
        end
      end
      context 'with TOS set' do
        let(:tos) { 5 }
        before { socket.options.tos = tos }
        it 'returns TOS' do
          assert_equal tos, socket.options.tos
        end
      end
      context 'with invalid TOS' do
        it 'raises' do
          assert_raises(ArgumentError) { socket.options.tos = -5 }
        end
      end
      context 'when resetting to zero' do
        before { socket.options.tos = 10 }
        it "doesn't raise" do
          socket.options.tos = 0
        end
      end
    end
    describe '#heartbeat_ivl', if: (has_zmq_version?('4.2') && has_czmq_drafts?) do
      context 'with no IVL' do
        it 'returns zero' do
          assert_equal 0, socket.options.heartbeat_ivl
        end
      end
      context 'with IVL set' do
        let(:ivl) { 5 }
        before { socket.options.heartbeat_ivl = ivl }
        it 'returns IVL' do
          assert_equal ivl, socket.options.heartbeat_ivl
        end
      end
    end
    describe '#heartbeat_ttl', if: (has_zmq_version?('4.2') && has_czmq_drafts?) do
      context 'with no TTL' do
        it 'returns zero' do
          assert_equal 0, socket.options.heartbeat_ttl
        end
      end
      context 'with TTL set' do
        let(:ttl) { 500 }
        before { socket.options.heartbeat_ttl = ttl }
        it 'returns TTL' do
          assert_equal ttl, socket.options.heartbeat_ttl
        end
      end
      context 'with invalid TTL' do
        let(:ttl) { 500.3 }
        it 'raises' do
          assert_raises(ArgumentError) { socket.options.heartbeat_ttl = ttl }
        end
      end
      context 'with out-of-range TTL' do
        let(:ttl) { 100_000 }
        it 'raises' do
          assert_raises(ArgumentError) { socket.options.heartbeat_ttl = ttl }
        end
      end
      context 'with insignificant TTL' do
        let(:ttl) { 80 } # less than 100
        before { socket.options.heartbeat_ttl = ttl }
        it 'has no effect' do
          assert_equal 0, socket.options.heartbeat_ttl
        end
      end
    end
    describe '#heartbeat_timeout', if: (has_zmq_version?('4.2') && has_czmq_drafts?) do
      context 'with no timeout' do
        it 'returns -1' do
          assert_equal(-1, socket.options.heartbeat_timeout)
        end
      end
      context 'with timeout set' do
        let(:timeout) { 5 }
        before { socket.options.heartbeat_timeout = timeout }
        it 'returns timeout' do
          assert_equal timeout, socket.options.heartbeat_timeout
        end
      end
      context 'integration test' do
        let(:timeout) { 50 }
        i = 55_556
        let(:endpoint) { "tcp://127.0.0.1:#{i += 1}" }
        let(:server_socket) do
          socket = CZTop::Socket::SERVER.new
          socket.options.linger = 0
          socket.options.heartbeat_ivl = 20
          socket.options.heartbeat_timeout = 100
          socket.bind(endpoint)
          socket
        end
        let(:client_socket) do
          socket = CZTop::Socket::CLIENT.new
          socket.connect(endpoint)
          socket
        end
        let(:server_mon) do
          mon = CZTop::Monitor.new(server_socket)
          mon.listen(*%w[CONNECTED DISCONNECTED ACCEPTED])
          mon.start
          mon.actor.options.rcvtimeo = 50
          mon
        end

        let(:accepted_event) do
          assert_equal 'ACCEPTED', server_mon.next[0]
        end
        let(:disconnected_event) do
          assert_equal 'DISCONNECTED', server_mon.next[0]
        end

        context 'with client connected' do
          before do
            server_socket
            server_mon
            client_socket
          end
          it 'accepts connection' do
            accepted_event
          end
        end
        context 'with client socket dead' do
          before do
            server_socket
            server_mon
            client_socket
            accepted_event

            # NOTE: Disconnecting alone won't do it. It has to be destroyed.
            client_socket.ffi_delegate.destroy
          end

          it 'closes connection' do
            disconnected_event
          rescue IO::EAGAINWaitReadable
            flunk "client wasn't disconnected"
          end
        end
        context 'with talking and then dead client socket' do
          let(:received_msg) { server_socket.receive } # to know the routing ID
          before do
            server_socket
            server_socket.options.sndtimeo = 30 # so we'll get an exception
            server_mon
            client_socket
            accepted_event
            client_socket << 'foo'
            assert_equal %w[foo], received_msg.to_a

            # NOTE: Disconnecting alone won't do it. It has to be destroyed.
            client_socket.ffi_delegate.destroy

            disconnected_event
          end

          let(:test_msg) do
            msg = CZTop::Message.new 'bar'
            msg.routing_id = received_msg.routing_id
            msg
          end

          context 'when server sends message' do
            it 'raises' do
              assert_raises(IO::EAGAINWaitWritable) do
                server_socket << test_msg
              end
            end
          end
        end
      end
    end

    describe '#linger' do
      context 'with no LINGER' do
        it 'returns default' do
          assert_equal 0, socket.options.linger # ZMQ docs say 30_000, but they're wrong
        end
      end
      context 'with LINGER set' do
        let(:linger) { 500 }
        before { socket.options.linger = linger }
        it 'returns LINGER' do
          assert_equal linger, socket.options.linger
        end
      end
    end

    describe '#ipv6=' do
      it 'can enable IPv6' do
        expect(CZMQ::FFI::Zsock).to receive(:set_ipv6).with(socket, 1)
        socket.options.ipv6 = true
      end
      it 'can disable IPv6' do
        expect(CZMQ::FFI::Zsock).to receive(:set_ipv6).with(socket, 0)
        socket.options.ipv6 = false
      end
    end
    describe '#ipv6?' do
      context 'with default setting' do
        it 'returns false' do
          refute_operator socket.options, :ipv6?
        end
      end
      context 'with ipv6 enabled' do
        before { socket.options.ipv6 = true }
        it 'returns true' do
          assert_operator socket.options, :ipv6?
        end
      end
      context 'with ipv6 disabled' do
        before { socket.options.ipv6 = false }
        it 'returns false' do
          refute_operator socket.options, :ipv6?
        end
      end
    end

    describe '#[]' do
      context 'with vague option name' do
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
      context 'with plain wrong option name' do
        it 'raises' do
          assert_raises(NoMethodError) { socket.options[:foo] }
          assert_raises(NoMethodError) { socket.options[5] }
          assert_raises(NoMethodError) { socket.options['!!'] }
        end
      end
    end
    describe '#[]=' do
      let(:identity) { 'foobar' }
      let(:tos) { 5 }
      before do
        socket.options[:IDENTITY] = identity
        socket.options[:ToS] = tos
      end
      context 'with vague option name' do
        it 'sets option' do
          assert_equal identity, socket.options.identity
          assert_equal tos, socket.options.tos
        end
      end
      context 'with plain wrong option name' do
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
      context 'with no RECONNECT_IVL' do
        it 'returns default' do
          assert_equal 100, socket.options.reconnect_ivl
        end
      end
      context 'with RECONNECT_IVL set' do
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
      context 'with readable socket' do
        before { writer << 'foo' }
        it 'is readable' do
          assert (reader.options.events & CZTop::Poller::ZMQ::POLLIN) > 0,
                 'should be readable'
        end
      end
      context 'with non-readable socket' do
        it 'is not readable' do
          assert (reader.options.events & CZTop::Poller::ZMQ::POLLIN) == 0,
                 'should not be readable'
        end
      end
      context 'with writable socket' do
        it 'is writable' do
          assert (writer.options.events & CZTop::Poller::ZMQ::POLLOUT) > 0,
                 'should be writable'
        end
      end
      context 'with non-writable socket' do
        let(:full_writer) do
          sock = CZTop::Socket::PUSH.new
          sock.options.sndhwm = 1 # set SNDHWM option before connecting
          sock.connect(endpoint)
          sock << 'is now full'
          sock
        end
        it 'is not writable' do
          assert (full_writer.options.events & CZTop::Poller::ZMQ::POLLOUT) == 0,
                 'should not be writable'
        end
      end
    end
  end
end
