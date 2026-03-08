# frozen_string_literal: true

require_relative '../spec_helper'


describe 'CZTop::Proxy::ZPROXY_FPTR' do
  it 'points to a dynamic library symbol' do
    assert_kind_of FFI::DynamicLibrary::Symbol, CZTop::Proxy::ZPROXY_FPTR
  end
end


describe CZTop::Proxy do
  let(:proxy) { CZTop::Proxy.new }
  let(:actor) { proxy.actor }

  after do
    proxy.terminate
  end

  it 'initializes and terminates' do
    proxy
  end


  describe '#verbose' do
    it 'sends correct message to actor' do
      sent = nil
      original_send = actor.method(:<<)
      actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
        proxy.verbose!
      end
      assert_equal 'VERBOSE', sent
    end
  end


  describe '#frontend' do
    it 'returns configurator' do
      assert_kind_of CZTop::Proxy::Configurator, proxy.frontend
    end

    it 'memoizes it' do
      assert_same proxy.frontend, proxy.frontend
    end
  end


  describe '#backend' do
    it 'returns configurator' do
      assert_kind_of CZTop::Proxy::Configurator, proxy.backend
    end

    it 'memoize it' do
      assert_same proxy.backend, proxy.backend
    end
  end


  describe '#capture' do
    i = 0
    let(:endpoint) { "inproc://proxy_capture_spec_#{i += 1}" }


    describe 'with endpoint' do
      it 'tells zproxy to capture' do
        sent = nil
        original_send = actor.method(:<<)
        actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
          proxy.capture(endpoint)
        end
        assert_equal ['CAPTURE', endpoint], sent
      end
    end
  end


  describe '#pause' do
    it 'tells zproxy to pause' do
      sent = nil
      original_send = actor.method(:<<)
      actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
        proxy.pause
      end
      assert_equal 'PAUSE', sent
    end
  end


  describe '#resume' do
    it 'tells zproxy to resume' do
      sent = nil
      original_send = actor.method(:<<)
      actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
        proxy.resume
      end
      assert_equal 'RESUME', sent
    end
  end


  describe CZTop::Proxy::Configurator do
    let(:configurator) { CZTop::Proxy::Configurator.new(proxy, side) }
    let(:side) { :frontend } # default for specs


    describe '#initialize' do
      describe 'with proxy' do
        it 'assigns proxy' do
          assert_equal proxy, configurator.proxy
        end
      end


      describe 'with frontend side argument' do
        let(:side) { :frontend }

        it 'assigns side' do
          assert_equal 'FRONTEND', configurator.side
        end
      end


      describe 'with backend side argument' do
        let(:side) { :backend }

        it 'assigns side' do
          assert_equal 'BACKEND', configurator.side
        end
      end


      describe 'with wrong side argument' do
        let(:side) { :foo }

        it 'raises' do
          assert_raises(ArgumentError) { configurator }
        end
      end
    end


    describe '#proxy' do
      it 'returns proxy' do
        assert_same proxy, configurator.proxy
      end
    end


    describe '#side' do
      it 'returns string' do
        # NOTE: functionality already tested in #initialize
        assert_kind_of String, configurator.side
      end
    end


    describe '#bind' do
      i = 0
      let(:endpoint) { "inproc://proxy_bind_spec_#{i += 1}" }


      describe 'with valid arguments' do
        describe 'for frontend' do
          let(:side) { :frontend }
          let(:socket_type) { :ROUTER }

          it 'configures frontend socket' do
            sent = nil
            original_send = actor.method(:<<)
            actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
              configurator.bind(socket_type, endpoint)
            end
            assert_equal ['FRONTEND', 'ROUTER', endpoint], sent
          end
        end


        describe 'for backend' do
          let(:side) { :backend }
          let(:socket_type) { :DEALER }

          it 'configures backend socket' do
            sent = nil
            original_send = actor.method(:<<)
            actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
              configurator.bind(socket_type, endpoint)
            end
            assert_equal ['BACKEND', 'DEALER', endpoint], sent
          end
        end
      end


      describe 'with invalid socket type' do
        let(:type) { :foo }

        it 'raises' do
          assert_raises(ArgumentError) { configurator.bind(type, endpoint) }
        end
      end
    end


    describe '#domain=' do
      let(:domain) { 'foobar' }


      describe 'for frontend' do
        let(:side) { :frontend }

        it 'tells actor the ZAP domain' do
          sent = nil
          original_send = actor.method(:<<)
          actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
            configurator.domain = domain
          end
          assert_equal ['DOMAIN', 'FRONTEND', domain], sent
        end
      end


      describe 'for backend' do
        let(:side) { :backend }

        it 'tells actor the ZAP domain' do
          sent = nil
          original_send = actor.method(:<<)
          actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
            configurator.domain = domain
          end
          assert_equal ['DOMAIN', 'BACKEND', domain], sent
        end
      end
    end


    describe '#PLAIN!' do
      describe 'for frontend' do
        let(:side) { :frontend }

        it 'tells actor to configure PLAIN' do
          sent = nil
          original_send = actor.method(:<<)
          actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
            configurator.PLAIN_server!
          end
          assert_equal ['PLAIN', 'FRONTEND'], sent
        end
      end


      describe 'for backend' do
        let(:side) { :backend }

        it 'tells actor to configure PLAIN' do
          sent = nil
          original_send = actor.method(:<<)
          actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
            configurator.PLAIN_server!
          end
          assert_equal ['PLAIN', 'BACKEND'], sent
        end
      end
    end


    describe '#CURVE!' do
      before { skip 'requires CURVE' unless ::CZMQ::FFI::Zsys.has_curve }

      let(:cert) { CZTop::Certificate.new }
      let(:public_key) { cert.public_key }
      let(:secret_key) { cert.secret_key }


      describe 'with correct arguments' do
        describe 'for frontend' do
          let(:side) { :frontend }

          it 'tells actor to configure CURVE' do
            sent = nil
            original_send = actor.method(:<<)
            actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
              configurator.CURVE_server!(cert)
            end
            assert_equal ['CURVE', 'FRONTEND', public_key, secret_key], sent
          end
        end


        describe 'for backend' do
          let(:side) { :backend }

          it 'tells actor to configure CURVE' do
            sent = nil
            original_send = actor.method(:<<)
            actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
              configurator.CURVE_server!(cert)
            end
            assert_equal ['CURVE', 'BACKEND', public_key, secret_key], sent
          end
        end
      end


      describe 'with secret key missing' do
        it 'raises' do
          cert.stub(:secret_key, nil) do
            assert_raises(ArgumentError) { configurator.CURVE_server!(cert) }
          end
        end
      end
    end
  end
end
