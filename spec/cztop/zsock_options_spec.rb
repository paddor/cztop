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
    describe "#curve_server" do
      it "sets and gets CURVE server flag" do
        refute options.curve_server?
        options.curve_server = true
        assert options.curve_server?
        options.curve_server = false
        refute options.curve_server?
      end

      it "is mutually exclusive with PLAIN" do
        options.curve_server = true
        options.plain_server = true
        refute_operator options, :curve_server?
      end
    end

    describe "#curve_serverkey" do
      context "with key not set" do
        it "returns nil" do
          assert_nil options.curve_serverkey
        end
      end
      context "with valid key" do
        let(:cert) { CZTop::Certificate.new }
        let(:key_bin) { cert.public_key(format: :binary) }
        let(:key_z85) { cert.public_key(format: :z85) }
        context "as binary" do
          When { options.curve_serverkey = key_bin }
          Then { key_z85 == options.curve_serverkey }
        end
        context "as Z85" do
          When { options.curve_serverkey = key_z85 }
          Then { key_z85 == options.curve_serverkey }
        end
      end
      context "with invalid key" do
        it "raises" do
          assert_raises(ArgumentError) { options.curve_serverkey = "foo" }
          assert_raises { options.curve_serverkey = nil }
        end
      end
    end

    describe "#curve_secretkey" do
      context "with key not set" do
        Then { options.curve_secretkey.nil? }
      end
      context "with valid key" do
        let(:cert) { CZTop::Certificate.new }
        let(:key_bin) { cert.secret_key(format: :binary) }
        let(:key_z85) { cert.secret_key(format: :z85) }
        When { cert.apply(socket) }
        Then { key_z85 == options.curve_secretkey }
      end
      context "with only CURVE mechanism enabled but no key set" do
        When { options.curve_server = true } # just enable CURVE
        Then { options.curve_secretkey.is_a? String }
        And { not options.curve_secretkey.empty? }
      end
    end

    describe "#mechanism" do
      context "with no security" do
        it "returns :null" do
          assert_equal :null, options.mechanism
        end
      end
      context "with PLAIN security" do
        When { options.plain_server = true }
        Then { :plain == options.mechanism }
      end
      context "with CURVE security" do
        When { options.curve_server = true }
        Then {:curve == options.mechanism }
      end
      context "with GSSAPI security" do
        it "returns :gssapi"
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

    describe "#plain_server" do
      it "sets and gets PLAIN server flag" do
        refute options.plain_server?
        options.plain_server = true
        assert options.plain_server?
        options.plain_server = false
        refute options.plain_server?
      end

      it "is mutually exclusive with CURVE" do
        options.plain_server = true
        options.curve_server = true
        refute_operator options, :plain_server?
      end
    end
    describe "#plain_username" do
      context "with no username set" do
        Then { options.plain_username.nil? }
      end
      context "setting and getting" do
        Given(:username) { "foo" }
        When { options.plain_username = username }
        Then { username == options.plain_username }
      end
    end
    describe "#plain_password" do
      context "with not PLAIN mechanism" do
        Then { options.plain_password.nil? }
      end
      context "with password set" do
        Given(:password) { "secret" }
        When { options.plain_password = password }
        Then { options.plain_password == password }
      end
      context "with only username set" do
        When { options.plain_username = "foo" }
        Then { "" == options.plain_password }
      end
      context "setting and getting" do
        Given(:password) { "foo" }
        When { options.plain_password = password }
        When { password == options.plain_password }
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
    end
  end
end
