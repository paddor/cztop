require_relative 'spec_helper'

describe CZTop::ZAP do
  i = 0
  let(:endpoint) { "inproc://endpoint_zap_spec_#{i+=1}" }
  let(:req_socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:rep_socket) { CZTop::Socket::REP.new(endpoint) }


  it "is a has a version" do
    assert_kind_of String, CZTop::ZAP::VERSION
  end
  it "knows ZAP endpoint" do
    assert_kind_of String, CZTop::ZAP::ENDPOINT
  end

  describe CZTop::ZAP::Error do
    it "is a StandardError" do
      assert_equal StandardError, CZTop::ZAP::Error.superclass
    end
  end

  describe CZTop::ZAP::VersionMismatch do
    it "is an Error" do
      assert_equal CZTop::ZAP::Error, CZTop::ZAP::VersionMismatch.superclass
    end
  end

  describe CZTop::ZAP::Mechanisms do
    it "it knows NULL" do
      assert_equal "NULL", CZTop::ZAP::Mechanisms::NULL
    end
    it "it knows PLAIN" do
      assert_equal "PLAIN", CZTop::ZAP::Mechanisms::PLAIN
    end
    it "it knows CURVE" do
      assert_equal "CURVE", CZTop::ZAP::Mechanisms::CURVE
    end
  end

  describe CZTop::ZAP::Request do
    let(:version) { "1.0" }
    let(:request_id) { "request 42" }
    let(:domain) { "global" }
    let(:address) { "1.2.3.4" }
    let(:identity) { "john_doe" }
    let(:mechanism) { "PLAIN" }
    let(:credentials) { %w[ john66 pass1234 ] }

    describe ".from_message" do
      let(:msg) do
        fields = [version, request_id, domain, address,
                  identity, mechanism, *credentials]
        CZTop::Message.new(fields)
      end

      let(:request) { CZTop::ZAP::Request.from_message(msg) }

      context "with valid request message" do
        it "builds a request" do
          assert_kind_of CZTop::ZAP::Request, request
        end
        it "builds request correctly" do
          assert_equal version, request.version
          assert_equal request_id, request.request_id
          assert_equal domain, request.domain
          assert_equal address, request.address
          assert_equal identity, request.identity
          assert_equal mechanism, request.mechanism
          assert_equal credentials, request.credentials
        end
      end
      context "with invalid version" do
        let(:version) { "0.9" }
        it "raises" do
          assert_raises(CZTop::ZAP::VersionMismatch) do
            request
          end
        end
      end
    end

    describe "#initialize" do
      context "with only domain and credentials" do
        let(:domain) { "example.com" }
        let(:credentials) { %w[ user pass ] }
        subject { CZTop::ZAP::Request.new(domain, credentials) }

        it "sets domain" do
          assert_equal domain, subject.domain
        end
        it "sets credentials" do
          assert_equal credentials, subject.credentials
        end
        it "sets CURVE mechanism" do
          assert_equal "CURVE", subject.mechanism
        end
        it "sets default version" do
          assert_equal "1.0", subject.version
        end
      end

      context "with only a domain" do
        let(:domain) { "example.com" }
        subject { CZTop::ZAP::Request.new(domain) }

        it "sets credentials to empty array" do
          assert_equal [], subject.credentials
        end
        it "sets default version" do
          assert_equal "1.0", subject.version
        end
      end
    end

    describe "#to_msg" do
      let(:msg) { request.to_msg }

      context "with no credentials" do
        let(:request) { CZTop::ZAP::Request.new(domain) }
        it "doesn't include credential frames" do
          assert_equal 6, msg.size
        end
      end
      context "with credentials" do
        let(:request) { CZTop::ZAP::Request.new(domain, %w[one two three]) }
        it "includes credential frames" do
          assert_equal 9, msg.size
        end
      end
    end

  end

  describe CZTop::ZAP::Response do
    let(:version) { "1.0" }
    let(:request_id) { "request 42" }
    let(:status_code) { "200" }
    let(:status_text) { "Welcome!" }
    let(:user_id) { "jane77" }
    let(:meta_data) { "properties in ZMTP 3.0 format" }

    subject do
      CZTop::ZAP::Response.new(status_code).tap do |r|
        r.version = version
        r.request_id = request_id
        r.status_code = status_code
        r.status_text = status_text
        r.user_id = user_id
        r.meta_data = meta_data
      end
    end

    describe ".from_message" do
      let(:msg) do
        fields = [version, request_id, status_code, status_text,
                  user_id, meta_data].map(&:to_s)
        CZTop::Message.new(fields)
      end
      subject { CZTop::ZAP::Response.from_message(msg) }

      context "given a valid response message" do
        it "builds a response" do
          assert_kind_of CZTop::ZAP::Response, subject
        end
        it "builds response correctly" do
          assert_equal version, subject.version
          assert_equal request_id, subject.request_id
          assert_equal status_code, subject.status_code
          assert_equal status_text, subject.status_text
          assert_equal user_id, subject.user_id
          assert_equal meta_data, subject.meta_data
        end
      end

      context "given invalid version" do
        let(:version) { "0.9" }
        it "raises" do
          assert_raises(CZTop::ZAP::VersionMismatch) do
            subject
          end
        end
      end
      context "given status code for temporary failure" do
        let(:status_code) { 300 }
        it "raises" do
          assert_raises(CZTop::ZAP::Response::TemporaryError) do
            subject
          end
        end
      end
      context "given status code for internal error" do
        let(:status_code) { 500 }
        it "raises" do
          assert_raises(CZTop::ZAP::Response::InternalError) do
            subject
          end
        end
      end
      context "given invalid status code" do
        let(:status_code) { 666 }
        it "raises" do
          assert_raises(CZTop::ZAP::Response::InternalError) do
            subject
          end
        end
      end
    end

    describe "#initialize" do
      subject { described_class.new(status_code) }
      it "sets default version" do
        assert_equal "1.0", subject.version
      end
      context "with valid status code" do
        let(:status_code) { 500 }
        it "initializes" do
          subject
        end
      end
      context "with invalid status code" do
        let(:status_code) { 333 }
        it "raises" do
          assert_raises(ArgumentError) do
            subject
          end
        end
      end
    end
    describe "#success?" do
      let(:status_code) { "200" }
      context "with successful authentication" do
        it "returns true" do
          assert_operator subject, :success?
        end
      end
      context "with failed authentication" do
        let(:status_code) { "400" }
        it "returns false" do
          refute_operator subject, :success?
        end
      end
    end
    describe "#to_msg" do
      let(:fields) do
        [ version, request_id, status_code, status_text, user_id, meta_data ]
      end
      it "packs response into a message" do
        assert_equal fields, subject.to_msg.to_a
      end
    end
    describe "#user_id" do
      context "when authenticated" do
        it "returns user ID" do
          assert_equal user_id, subject.user_id
        end
      end
      context "when not authenticated" do
        let(:status_code) { "300" }
        it "returns nil" do
          assert_nil subject.user_id
        end
      end
    end
    describe "#meta_data" do
      context "when authenticated" do
        it "returns meta data" do
          assert_equal meta_data, subject.meta_data
        end
      end
      context "when not authenticated" do
        let(:status_code) { "300" }
        it "returns meta data" do
          assert_nil subject.meta_data
        end
      end
    end
  end
end
