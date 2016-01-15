require_relative 'spec_helper'

describe CZTop::ZsockOptions do
  i = 0
  let(:endpoint) { "inproc://endpoint_zsock_options_#{i+=1}" }
  let(:socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:options) { socket.options }

  describe "#options" do
    it "returns options proxy" do
      assert_kind_of CZTop::ZsockOptions::OptionsAccessor, options
    end

    it "changes the correct socket's options" do
      assert_same socket, options.zocket
    end
  end

  describe CZTop::ZsockOptions::OptionsAccessor do
    describe "#sndhwm" do
      context "when getting current value" do
        it "returns value" do
          assert_kind_of Integer, options.sndhwm
        end
      end
      context "when setting new value" do
        let(:new_value) { 99 }
        before(:each) { options.sndhwm = new_value }
        it "sets new value" do
          assert_equal new_value, options.sndhwm
        end
      end
    end
    describe "#rcvhwm" do
      context "when getting current value" do
        it "returns value" do
          assert_kind_of Integer, options.rcvhwm
        end
      end
      context "when setting new value" do
        let(:new_value) { 99 }
        before(:each) { options.rcvhwm = new_value }
        it "sets new value" do
          assert_equal new_value, options.rcvhwm
        end
      end
    end
    describe "#CURVE_server" do
      it "sets and gets CURVE server flag" do
        refute options.CURVE_server?
        options.CURVE_server = true
        assert options.CURVE_server?
        options.CURVE_server = false
        refute options.CURVE_server?
      end

      it "is mutually exclusive with PLAIN" do
        options.CURVE_server = true
        options.PLAIN_server = true
        refute_operator options, :CURVE_server?
      end
    end

    describe "#CURVE_serverkey" do
      context "with key not set" do
        it "returns nil" do
          assert_nil options.CURVE_serverkey
        end
      end
      context "with valid key" do
        let(:cert) { CZTop::Certificate.new }
        let(:key_bin) { cert.public_key(format: :binary) }
        let(:key_z85) { cert.public_key(format: :z85) }
        context "as binary" do
          When { options.CURVE_serverkey = key_bin }
          Then { key_z85 == options.CURVE_serverkey }
        end
        context "as Z85" do
          When { options.CURVE_serverkey = key_z85 }
          Then { key_z85 == options.CURVE_serverkey }
        end
      end
      context "with invalid key" do
        it "raises" do
          assert_raises(ArgumentError) { options.CURVE_serverkey = "foo" }
          assert_raises { options.CURVE_serverkey = nil }
        end
      end
    end

    describe "#CURVE_secretkey" do
      context "with key not set" do
        Then { options.CURVE_secretkey.nil? }
      end
      context "with valid key" do
        let(:cert) { CZTop::Certificate.new }
        let(:key_bin) { cert.secret_key(format: :binary) }
        let(:key_z85) { cert.secret_key(format: :z85) }
        When { cert.apply(socket) }
        Then { key_z85 == options.CURVE_secretkey }
      end
      context "with only CURVE mechanism enabled but no key set" do
        When { options.CURVE_server = true } # just enable CURVE
        Then { options.CURVE_secretkey.is_a? String }
        And { not options.CURVE_secretkey.empty? }
      end
    end

    describe "#mechanism" do
      context "with no security" do
        it "returns :NULL" do
          assert_equal :NULL, options.mechanism
        end
      end
      context "with PLAIN security" do
        When { options.PLAIN_server = true }
        Then { :PLAIN == options.mechanism }
      end
      context "with CURVE security" do
        When { options.CURVE_server = true }
        Then { :CURVE == options.mechanism }
      end
      context "with GSSAPI security" do
        it "returns :GSSAPI"
      end
      context "with unknown security mechanism" do
        before(:each) do
          expect(CZMQ::FFI::Zsock).to receive(:mechanism)
            .with(socket).and_return(99)
        end
        it "raises" do
          assert_raises { options.mechanism }
        end
      end
    end

    describe "#zap_domain" do
      context "with no ZAP domain set" do
        Then { "" == options.zap_domain }
      end
      context "with valid ZAP domain" do
        Given(:domain) { "foobar" }
        When { options.zap_domain = domain }
        Then { domain == options.zap_domain }
      end
      context "with too long ZAP domain" do
        Given(:domain) { "o" * 255 }
        When(:result) { options.zap_domain = domain }
        Then { result == Failure(ArgumentError) }
      end
    end

    describe "#PLAIN_server" do
      it "sets and gets PLAIN server flag" do
        refute options.PLAIN_server?
        options.PLAIN_server = true
        assert options.PLAIN_server?
        options.PLAIN_server = false
        refute options.PLAIN_server?
      end

      it "is mutually exclusive with CURVE" do
        options.PLAIN_server = true
        options.CURVE_server = true
        refute_operator options, :PLAIN_server?
      end
    end
    describe "#PLAIN_username" do
      context "with no username set" do
        Then { options.PLAIN_username.nil? }
      end
      context "setting and getting" do
        Given(:username) { "foo" }
        When { options.PLAIN_username = username }
        Then { username == options.PLAIN_username }
      end
    end
    describe "#PLAIN_password" do
      context "with not PLAIN mechanism" do
        Then { options.PLAIN_password.nil? }
      end
      context "with password set" do
        Given(:password) { "secret" }
        When { options.PLAIN_password = password }
        Then { options.PLAIN_password == password }
      end
      context "with only username set" do
        When { options.PLAIN_username = "foo" }
        Then { "" == options.PLAIN_password }
      end
      context "setting and getting" do
        Given(:password) { "foo" }
        When { options.PLAIN_password = password }
        When { password == options.PLAIN_password }
      end
    end

    describe "#sndtimeo" do
      it "sets and gets send timeout" do
        assert_equal -1, options.sndtimeo
        options.sndtimeo = 7
        assert_equal 7, options.sndtimeo
      end
    end

    describe "#rcvtimeo" do
      it "sets and gets receive timeout" do
        assert_equal -1, options.rcvtimeo
        options.rcvtimeo = 7
        assert_equal 7, options.rcvtimeo
      end
    end

    describe "#router_mandatory=" do
      let(:socket) { CZTop::Socket::ROUTER.new }

      it "can set the flag" do
        expect(CZMQ::FFI::Zsock).to receive(:set_router_mandatory)
          .with(socket, 1)
        options.router_mandatory = true
      end
      it "can unset the flag" do
        expect(CZMQ::FFI::Zsock).to receive(:set_router_mandatory)
          .with(socket, 0)
        options.router_mandatory = false
      end
      context "with flag set and message unroutable" do
        before(:each) { options.router_mandatory = true }
        let(:identity) { "receiver identity" }
        let(:content) { "foobar" }
        let(:msg) { [ identity, "", content ] }
        it "raises" do
          assert_raises(Errno::EHOSTUNREACH) { socket << msg }
        end
      end
    end

    describe "#identity" do
      context "with no identity set" do
        it "returns empty string" do
          assert_equal "", options.identity
        end
      end
      context "with identity set" do
        let(:identity) { "foobar" }
        before(:each) { options.identity = identity }
        it "returns identity" do
          assert_equal identity, options.identity
        end
      end
    end

    describe "#tos" do
      context "with no TOS" do
        it "returns zero" do
          assert_equal 0, options.tos
        end
      end
      context "with TOS set" do
        let(:tos) { 5 }
        before(:each) { options.tos = tos }
        it "returns TOS" do
          assert_equal tos, options.tos
        end
      end
      context "with invalid TOS" do
        it "raises" do
          assert_raises(ArgumentError) { options.tos = -5 }
        end
      end
      context "when resetting to zero" do
        before(:each) { options.tos = 10 }
        it "doesn't raise" do
          options.tos = 0
        end
      end
    end
    describe "#heartbeat_ivl" do
      context "with no IVL" do
        it "returns zero" do
          assert_equal 0, options.heartbeat_ivl
        end
      end
      context "with IVL set" do
        let(:ivl) { 5 }
        before(:each) { options.heartbeat_ivl = ivl }
        it "returns IVL" do
          assert_equal ivl, options.heartbeat_ivl
        end
      end
    end
    describe "#heartbeat_ttl" do
      context "with no TTL" do
        it "returns zero" do
          assert_equal 0, options.heartbeat_ttl
        end
      end
      context "with TTL set" do
        let(:ttl) { 500 }
        before(:each) { options.heartbeat_ttl = ttl }
        it "returns TTL" do
          assert_equal ttl, options.heartbeat_ttl
        end
      end
      context "with invalid TTL" do
        let(:ttl) { 500.3 }
        it "raises" do
          assert_raises(ArgumentError) { options.heartbeat_ttl = ttl }
        end
      end
      context "with out-of-range TTL" do
        let(:ttl) { 100_000 }
        it "raises" do
          assert_raises(ArgumentError) { options.heartbeat_ttl = ttl }
        end
      end
      context "with insignificant TTL" do
        let(:ttl) { 80 } # less than 100
        before(:each) { options.heartbeat_ttl = ttl }
        it "has no effect" do
          assert_equal 0, options.heartbeat_ttl
        end
      end
    end
    describe "#heartbeat_timeout" do
      context "with no timeout" do
        it "returns -1" do
          assert_equal -1, options.heartbeat_timeout
        end
      end
      context "with timeout set" do
        let(:timeout) { 5 }
        before(:each) { options.heartbeat_timeout = timeout }
        it "returns timeout" do
          assert_equal timeout, options.heartbeat_timeout
        end
      end
    end
  end
end
