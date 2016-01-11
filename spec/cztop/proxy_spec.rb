require_relative '../spec_helper'

describe "CZTop::Proxy::ZPROXY_FPTR" do
  it "points to a dynamic library symbol" do
    assert_kind_of FFI::DynamicLibrary::Symbol, CZTop::Proxy::ZPROXY_FPTR
  end
end

describe CZTop::Proxy do
  let(:proxy) { CZTop::Proxy.new }
  let(:actor) { proxy.actor }

  after(:each) do
    proxy.terminate
  end

  it "initializes and terminates" do
    proxy
  end

  describe "#verbose" do
    after(:each) { proxy.verbose! }
    it "sends correct message to actor" do
      expect(actor).to receive(:<<).with("VERBOSE").and_call_original
    end
    it "waits for signal" do
      # +1 for #terminate
      expect(actor).to receive(:wait).at_least(2).and_call_original
    end
  end

  describe "#frontend" do
    it "returns configurator" do
      assert_kind_of CZTop::Proxy::Configurator, proxy.frontend
    end
    it "memoizes it" do
      assert_same proxy.frontend, proxy.frontend
    end
  end

  describe "#backend" do
    it "returns configurator" do
      assert_kind_of CZTop::Proxy::Configurator, proxy.backend
    end
    it "memoize it" do
      assert_same proxy.backend, proxy.backend
    end
  end

  describe "#capture" do
    i = 0
    let(:endpoint) { "inproc://proxy_capture_spec_#{i+=1}" }
    context "with endpoint" do
      after(:each) { proxy.capture(endpoint) }
      it "tells zproxy to capture" do
        expect(actor).to receive(:<<).with(["CAPTURE", endpoint]).and_call_original
      end
      it "waits for signal" do
        # +1 for #terminate
        expect(actor).to receive(:wait).at_least(2).and_call_original
      end
    end

  end
  describe "#pause" do
    after(:each) { proxy.pause }
    it "tells zproxy to pause" do
      expect(actor).to receive(:<<).with("PAUSE").and_call_original
    end
    it "waits for signal" do
      # +1 for #terminate
      expect(actor).to receive(:wait).at_least(2).and_call_original
    end
  end
  describe "#resume" do
    after(:each) { proxy.resume }
    it "tells zproxy to resume" do
      expect(actor).to receive(:<<).with("RESUME").and_call_original
    end
    it "waits for signal" do
      # +1 for #terminate
      expect(actor).to receive(:wait).at_least(2).and_call_original
    end
  end

  describe CZTop::Proxy::Configurator do
    let(:configurator) { CZTop::Proxy::Configurator.new(proxy, side) }
    let(:side) { :frontend } # default for specs

    describe "#initialize" do

      context "with proxy" do
        it "assigns proxy" do
          assert_equal proxy, configurator.proxy
        end
      end
      context "with frontend side argument" do
        let(:side) { :frontend }
        it "assigns side" do
          assert_equal "FRONTEND", configurator.side
        end
      end
      context "with backend side argument" do
        let(:side) { :backend }
        it "assigns side" do
          assert_equal "BACKEND", configurator.side
        end
      end
      context "with wrong side argument" do
        let(:side) { :foo }
        it "raises" do
          assert_raises(ArgumentError) { configurator }
        end
      end
    end

    describe "#proxy" do
      it "returns proxy" do
        assert_same proxy, configurator.proxy
      end
    end
    describe "#side" do
      it "returns string" do
        # NOTE: functionality already tested in #initialize
        assert_kind_of String, configurator.side
      end
    end
    describe "#bind" do
      i = 0
      let(:endpoint) { "inproc://proxy_bind_spec_#{i+=1}" }

      context "with valid arguments" do
        before(:each) do
          # +1 for #terminate
          expect(actor).to receive(:wait).at_least(2).and_call_original
        end
        after(:each) do
          configurator.bind(socket_type, endpoint)
        end
        context "for frontend" do
          let(:side) { :frontend }
          let(:socket_type) { :ROUTER }
          it "configures frontend socket" do
            expect(actor).to receive(:<<)
              .with(["FRONTEND", "ROUTER", endpoint]).and_call_original
          end
        end
        context "for backend" do
          let(:side) { :backend }
          let(:socket_type) { :DEALER }
          it "configures backend socket" do
            expect(actor).to receive(:<<)
              .with(["BACKEND", "DEALER", endpoint]).and_call_original
          end
        end
      end
      context "with invalid socket type" do
        let(:type) { :foo }
        it "raises" do
          assert_raises(ArgumentError) { configurator.bind(type, endpoint) }
        end
      end
    end
    describe "#domain=" do
      let(:domain) { "foobar" }
      after(:each) { configurator.domain = domain }

      context "for frontend" do
        let(:side) { :frontend }
        it "tells actor the ZAP domain" do
          expect(actor).to receive(:<<)
            .with(["DOMAIN", "FRONTEND", domain]).and_call_original
        end
        it "waits for signal" do
          # +1 for #terminate
          expect(actor).to receive(:wait).at_least(2).and_call_original
        end
      end

      context "for backend" do
        let(:side) { :backend }
        it "tells actor the ZAP domain" do
          expect(actor).to receive(:<<)
            .with(["DOMAIN", "BACKEND", domain]).and_call_original
        end
        it "waits for signal" do
          # +1 for #terminate
          expect(actor).to receive(:wait).at_least(2).and_call_original
        end
      end
    end
    describe "#PLAIN!" do
      after(:each) { configurator.PLAIN_server! }

      context "for frontend" do
        let(:side) { :frontend }
        it "tells actor to configure PLAIN" do
          expect(actor).to receive(:<<)
            .with(["PLAIN", "FRONTEND"]).and_call_original
        end
        it "waits for signal" do
          # +1 for #terminate
          expect(actor).to receive(:wait).at_least(2).and_call_original
        end
      end

      context "for backend" do
        let(:side) { :backend }
        it "tells actor to configure PLAIN" do
          expect(actor).to receive(:<<)
            .with(["PLAIN", "BACKEND"]).and_call_original
        end
        it "waits for signal" do
          # +1 for #terminate
          expect(actor).to receive(:wait).at_least(2).and_call_original
        end
      end
    end
    describe "#CURVE!" do
      let(:cert) { CZTop::Certificate.new }
      let(:public_key) { cert.public_key }
      let(:secret_key) { cert.secret_key }

      context "with correct arguments" do
        after(:each) { configurator.CURVE_server!(cert) }

        context "for frontend" do
          let(:side) { :frontend }
          it "tells actor to configure CURVE" do
            expect(actor).to receive(:<<)
              .with(["CURVE", "FRONTEND", public_key, secret_key]).and_call_original
          end
          it "waits for signal" do
            # +1 for #terminate
            expect(actor).to receive(:wait).at_least(2).and_call_original
          end
        end

        context "for backend" do
          let(:side) { :backend }
          it "tells actor to configure CURVE" do
            expect(actor).to receive(:<<)
              .with(["CURVE", "BACKEND", public_key, secret_key]).and_call_original
          end
          it "waits for signal" do
            # +1 for #terminate
            expect(actor).to receive(:wait).at_least(2).and_call_original
          end
        end
      end

      context "with secret key missing" do
        before(:each) do
          expect(cert).to receive(:secret_key).and_return(nil)
        end
        it "raises" do
          assert_raises(ArgumentError) { configurator.CURVE_server!(cert) }
        end
      end
    end
  end
end
