# frozen_string_literal: true

require_relative '../spec_helper'


describe 'CZTop::Authenticator::ZAUTH_FPTR' do
  it 'points to a dynamic library symbol' do
    assert_kind_of FFI::DynamicLibrary::Symbol, CZTop::Authenticator::ZAUTH_FPTR
  end
end


describe CZTop::Authenticator do
  include ZMQHelper

  before { skip 'requires CURVE' unless ::CZMQ::FFI::Zsys.has_curve }

  let(:subject) { CZTop::Authenticator.new }
  let(:actor) { subject.actor }
  after { subject.terminate }

  it 'initializes' do
    subject
  end


  describe '#actor' do
    it 'returns an Actor' do
      assert_kind_of CZTop::Actor, actor
    end
  end


  describe '#verbose!' do
    it 'sends correct message to actor' do
      sent = nil
      original_send = actor.method(:<<)
      actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
        subject.verbose!
      end
      assert_equal 'VERBOSE', sent
    end
  end


  describe '#allow' do
    let(:addrs) { %w[1.1.1.1 2.2.2.2] }

    it 'whitelists addresses' do
      sent = nil
      original_send = actor.method(:<<)
      actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
        subject.allow(*addrs)
      end
      assert_equal ['ALLOW', *addrs], sent
    end
  end


  describe '#deny' do
    let(:addrs) { %w[3.3.3.3 4.4.4.4 foobar] }

    it 'blacklists addresses' do
      sent = nil
      original_send = actor.method(:<<)
      actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
        subject.deny(*addrs)
      end
      assert_equal ['DENY', *addrs], sent
    end
  end


  describe '#plain' do
    let(:filename) { '/path/to/file' }

    it 'enables PLAIN security' do
      sent = nil
      original_send = actor.method(:<<)
      actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
        subject.plain(filename)
      end
      assert_equal ['PLAIN', filename], sent
    end
  end


  describe '#curve' do
    describe 'when allowing keys from directory' do
      let(:directory) { '/path/to/directory' }

      it 'enables CURVE security for keys in directory' do
        sent = nil
        original_send = actor.method(:<<)
        actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
          subject.curve(directory)
        end
        assert_equal ['CURVE', directory], sent
      end
    end


    describe 'when allowing any key' do
      it 'enables CURVE security for any key' do
        sent = nil
        original_send = actor.method(:<<)
        actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
          subject.curve
        end
        assert_equal ['CURVE', '*'], sent
      end
    end
  end


  describe '#gssapi' do
    it 'enables GSSAPI security' do
      sent = nil
      original_send = actor.method(:<<)
      actor.stub(:<<, ->(*args) { sent = args[0]; original_send.call(*args) }) do
        subject.gssapi
      end
      assert_equal 'GSSAPI', sent
    end
  end


  describe 'with certificate store' do
    let(:subject) { CZTop::Authenticator.new(cert_store) }
    let(:cert_store) { CZTop::CertStore.new }
    let(:cert) { CZTop::Certificate.new }
    let(:pubkey_z85) { cert.public_key(format: :z85) }
    let(:pubkey_bin) { cert.public_key(format: :binary) }

    before do
      # cache key now, as certificate will be gone later
      pubkey_z85
      pubkey_bin

      cert_store.insert(cert)
    end

    after do
      subject.terminate
    end

    it 'initializes' do
      subject
    end

    it 'uses certificate store passed' do
      assert_kind_of CZTop::Certificate, cert
    end


    describe 'authentication' do
      let(:domain) { 'global' }
      let(:req) do
        # REQ socket acting as a CURVE server trying to authenticate a client
        CZTop::Socket::REQ.new(CZTop::ZAP::ENDPOINT)
      end
      rid = 0
      let(:request_id) { (rid += 1).to_s }
      let(:zap_request) do
        CZTop::ZAP::Request.new(domain, credentials).tap do |r|
          r.request_id = request_id
        end
      end

      let(:zap_response) { CZTop::ZAP::Response.from_message(req.receive) }

      before do
        subject # start authenticator
        req << zap_request.to_msg
      end


      describe 'with valid credentials' do
        let(:credentials) { [pubkey_bin] }

        it 'authenticates' do
          assert_operator zap_response, :success?
          assert_equal request_id, zap_response.request_id
        end
      end


      describe 'with invalid credentials' do
        let(:credentials) { ['f' * 32] } # unknown public key

        it 'does not authenticate' do
          refute_operator zap_response, :success?
          assert_equal request_id, zap_response.request_id
          assert_nil zap_response.user_id
        end
      end
    end
  end
end
