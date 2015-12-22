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
    describe "sndhwm" do
      context "getting current value" do
        it "returns value" do
          assert_kind_of Integer, options.sndhwm
        end
      end
      context "setting new value" do
        let(:new_value) { 99 }
        before(:each) { options.sndhwm = new_value }
        it "sets new value" do
          assert_equal new_value, options.sndhwm
        end
      end
    end
    describe "rcvhwm" do
      context "getting current value" do
        it "returns value" do
          assert_kind_of Integer, options.rcvhwm
        end
      end
      context "setting new value" do
        let(:new_value) { 99 }
        before(:each) { options.rcvhwm = new_value }
        it "sets new value" do
          assert_equal new_value, options.rcvhwm
        end
      end
    end
    describe "curve_server" do
      it "behaves correctly" do
        refute options.curve_server?
        options.curve_server = true
        assert options.curve_server?
        options.curve_server = false
        refute options.curve_server?
      end
    end

    describe "curve_serverkey" do
      context "unset key" do
        it "returns nil" do
          assert_nil options.curve_serverkey
        end
      end
      context "with valid key" do
        let(:cert) { CZTop::Certificate.new }
        let(:key_bin) { cert.public_key }
        let(:key_z85) { cert.public_key_txt }
        context "as binary" do
          it "behaves correctly" do
            options.curve_serverkey = key_bin
            assert_equal key_z85, options.curve_serverkey
          end
        end
        context "as Z85" do
          it "sets behaves correctly" do
            options.curve_serverkey = key_z85
            assert_equal key_z85, options.curve_serverkey
          end
        end
      end
      context "with invalid key" do
        it "raises" do
          assert_raises(ArgumentError) { options.curve_serverkey = "foo" }
          assert_raises { options.curve_serverkey = nil }
        end
      end
    end

    describe "mechanism" do
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
  end
end
