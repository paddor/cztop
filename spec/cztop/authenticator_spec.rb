# frozen_string_literal: true

require_relative '../spec_helper'

describe 'CZTop::Authenticator::ZAUTH_FPTR' do
  it 'points to a dynamic library symbol' do
    assert_kind_of FFI::DynamicLibrary::Symbol, CZTop::Authenticator::ZAUTH_FPTR
  end
end

describe CZTop::Authenticator do
  subject { CZTop::Authenticator.new }
  let(:actor) { subject.actor }
  after { subject.terminate }

  it 'initializes' do
    subject
  end

  describe '#actor' do
    Then { actor.is_a? CZTop::Actor }
  end

  describe '#verbose!' do
    after { subject.verbose! }
    it 'sends correct message to actor' do
      expect(actor).to receive(:<<).with('VERBOSE').and_call_original
    end
    it 'waits for signal' do
      expect(actor).to receive(:wait).and_call_original
    end
  end

  describe '#allow' do
    let(:addrs) { %w[1.1.1.1 2.2.2.2] }
    after { subject.allow(*addrs) }
    it 'whitelists addresses' do
      expect(actor).to receive(:<<).with(['ALLOW', *addrs]).and_call_original
    end
  end

  describe '#deny' do
    let(:addrs) { %w[3.3.3.3 4.4.4.4 foobar] }
    after { subject.deny(*addrs) }
    it 'blacklists addresses' do
      expect(actor).to receive(:<<).with(['DENY', *addrs]).and_call_original
    end
  end

  describe '#plain' do
    let(:filename) { '/path/to/file' }
    after { subject.plain(filename) }
    it 'enables PLAIN security' do
      expect(actor).to receive(:<<).with(['PLAIN', filename]).and_call_original
    end
  end

  describe '#curve' do
    context 'when allowing keys from directory' do
      let(:directory) { '/path/to/directory' }
      after { subject.curve(directory) }
      it 'enables CURVE security for keys in directory' do
        expect(actor).to receive(:<<).with(['CURVE', directory]).and_call_original
      end
    end
    context 'when allowing any key' do
      after { subject.curve }
      it 'enables CURVE security for any key' do
        expect(actor).to receive(:<<).with(['CURVE', '*']).and_call_original
      end
    end
  end

  describe '#gssapi' do
    after { subject.gssapi }
    it 'enables GSSAPI security' do
      expect(actor).to receive(:<<).with('GSSAPI').and_call_original
    end
  end

  describe 'with certificate store' do
    subject { CZTop::Authenticator.new(cert_store) }
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

    context 'authentication' do
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

      context 'with valid credentials' do
        let(:credentials) { [pubkey_bin] }
        it 'authenticates' do
          assert_operator zap_response, :success?
          assert_equal request_id, zap_response.request_id
        end
      end
      context 'with invalid credentials' do
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
