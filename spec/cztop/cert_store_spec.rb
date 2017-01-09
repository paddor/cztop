require_relative 'spec_helper'
require 'tmpdir'
require 'pathname'

describe CZTop::CertStore do
  include_examples "has FFI delegate"

  context "with disk location" do
    subject { CZTop::CertStore.new(location) }

    let(:location) do
      Pathname.new(Dir.mktmpdir("zcertstore_test"))
    end

    let(:cert1) { CZTop::Certificate.new }

    before do
      cert1.save(location + "cert1")
    end

    it "initializes" do
      subject
    end

    describe "#lookup" do
      context "with known public key" do
        let(:key) { cert1.public_key(format: :z85) }
        it "finds certificate" do
          assert_kind_of CZTop::Certificate, subject.lookup(key)
        end
      end
      context "with unknown public key" do
        let(:key) { CZTop::Certificate.new.public_key(format: :z85) }
        it "returns nil" do
          assert_nil subject.lookup(key)
        end
      end
    end

    describe "#insert" do
      context "with certificate" do
        let(:cert) { CZTop::Certificate.new }
        let(:key) { cert.public_key(format: :z85) }

        before do
          key # cache key now, cert will be gone later
          subject.insert(cert)
        end

        it "inserts certificate" do
          looked_up_cert = subject.lookup(key)
          assert_kind_of CZTop::Certificate, looked_up_cert
          assert_equal key, looked_up_cert.public_key
        end

        context 'when inserting duplicate certificate' do
          it 'raises ArgumentError' do
            assert_equal key, subject.lookup(key).public_key
            dup_cert = CZTop::Certificate.new_from key
            assert_raises(ArgumentError) { subject.insert(dup_cert) }
          end
        end
      end
      context "with invalid argument" do
        it "raises" do
          assert_raises(ArgumentError) do
            subject.insert(CZTop::Message.new("foo"))
          end
        end
      end
    end
  end

  context "without disk location" do
    subject { CZTop::CertStore.new }

    it "initializes" do
      subject
    end

    describe "#insert" do
      context "with certificate" do
        let(:cert) { CZTop::Certificate.new }
        let(:key) { cert.public_key(format: :z85) }

        before do
          key # cache key now, cert will be gone later
          subject.insert(cert)
        end

        it "inserts certificate" do
          looked_up_cert = subject.lookup(key)
          assert_kind_of CZTop::Certificate, looked_up_cert
          assert_equal key, looked_up_cert.public_key
        end
      end
      context "with invalid argument" do
        it "raises" do
          assert_raises(ArgumentError) do
            subject.insert(CZTop::Message.new("foo"))
          end
        end
      end
    end
  end
end
