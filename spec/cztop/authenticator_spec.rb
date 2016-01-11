require_relative '../spec_helper'

describe "CZTop::Authenticator::ZAUTH_FPTR" do
  it "points to a dynamic library symbol" do
    assert_kind_of FFI::DynamicLibrary::Symbol, CZTop::Authenticator::ZAUTH_FPTR
  end
end

describe CZTop::Authenticator do
  subject { CZTop::Authenticator.new }
  let(:actor) { subject.actor }
  after(:each) { subject.terminate }

  it "initializes" do
    subject
  end

  describe "#actor" do
    Then { actor.is_a? CZTop::Actor }
  end

  describe "#verbose!" do
    after(:each) { subject.verbose! }
    it "sends correct message to actor" do
      expect(actor).to receive(:<<).with("VERBOSE").and_call_original
    end
    it "waits for signal" do
      expect(actor).to receive(:wait).at_least(2).and_call_original
    end
  end

  describe "#allow" do
    let(:addrs) { %w[ 1.1.1.1 2.2.2.2 ] }
    after(:each) { subject.allow *addrs }
    it "whitelists addresses" do
      expect(actor).to receive(:<<).with(["ALLOW", *addrs]).and_call_original
    end
  end

  describe "#deny" do
    let(:addrs) { %w[ 3.3.3.3 4.4.4.4 foobar ] }
    after(:each) { subject.deny *addrs }
    it "blacklists addresses" do
      expect(actor).to receive(:<<).with(["DENY", *addrs]).and_call_original
    end
  end

  describe "#plain" do
    let(:filename) { "/path/to/file" }
    after(:each) { subject.plain(filename) }
    it "enables PLAIN security" do
      expect(actor).to receive(:<<).with(["PLAIN", filename]).and_call_original
    end
  end

  describe "#curve" do
    let(:directory) { "/path/to/directory" }
    after(:each) { subject.curve(directory) }
    it "enables CURVE security" do
      expect(actor).to receive(:<<).with(["CURVE", directory]).and_call_original
    end
  end

  describe "#gssapi" do
    after(:each) { subject.gssapi }
    it "enables GSSAPI security" do
      expect(actor).to receive(:<<).with("GSSAPI").and_call_original
    end
  end
end
