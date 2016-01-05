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
    it "sends correct message to actor" do
      expect(actor).to receive(:<<).with("VERBOSE").and_call_original
      subject.verbose!
    end
  end

  describe "#allow" do
    let(:addrs) { %w[ 1.1.1.1 2.2.2.2 ] }
    before(:each) do
      expect(actor).to receive(:<<).with(["ALLOW", *addrs]).and_call_original
    end
    it "whitelists addresses" do
      subject.allow *addrs
    end
  end

  describe "#deny" do
    let(:addrs) { %w[ 3.3.3.3 4.4.4.4 foobar ] }
    before(:each) do
      expect(actor).to receive(:<<).with(["DENY", *addrs]).and_call_original
    end
    it "blacklists addresses" do
      subject.deny *addrs
    end

  end

  describe "#plain" do
    let(:filename) { "/path/to/file" }
    before(:each) do
      expect(actor).to receive(:<<).with(["PLAIN", filename]).and_call_original
    end
    it "enables PLAIN security" do
      subject.plain(filename)
    end
  end

  describe "#curve" do
    let(:directory) { "/path/to/directory" }
    before(:each) do
      expect(actor).to receive(:<<).with(["CURVE", directory]).and_call_original
    end
    it "enables CURVE security" do
      subject.curve(directory)
    end
  end

  describe "#gssapi" do
    before(:each) do
      expect(actor).to receive(:<<).with("GSSAPI").and_call_original
    end
    it "enables GSSAPI security" do
      subject.gssapi
    end
  end
end
