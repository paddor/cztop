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
        let(:key_bin) { cert.public_key(format: :binary) }
        let(:key_z85) { cert.public_key(format: :z85) }
        context "as binary" do
          When { options.curve_secretkey = key_bin }
          Then { key_z85 == options.curve_secretkey }
        end
        context "as Z85" do
          When { options.curve_secretkey = key_z85 }
          Then { key_z85 == options.curve_secretkey }
        end
      end
      context "with invalid key" do
        it "raises" do
          assert_raises(ArgumentError) { options.curve_secretkey = "foo" }
          assert_raises { options.curve_secretkey = nil }
        end
      end
    end

    describe "#mechanism" do
      context "with no security" do
        it "returns :null" do
          assert_equal :null, options.mechanism
        end
      end
      context "with PLAIN security" do
        it "returns :plain"
      end
      context "with CURVE security" do
        before(:each) { options.curve_serverkey = "X" * 40 }
        it "returns :curve" do
          assert_equal :curve, options.mechanism
        end
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
  end
end
