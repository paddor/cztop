require_relative 'spec_helper'
require 'tmpdir'
require 'pathname'

describe CZTop::Certificate do
  include_examples "has FFI delegate"

  context "with certificate" do
    let(:cert) { CZTop::Certificate.new }
    let(:ffi_delegate) { cert.ffi_delegate }
    describe "#initialize" do
      Then { cert }
    end

    describe "#public_key" do
      context "with :z85 format" do
        Given(:key) { cert.public_key(format: :z85) }
        Then { Encoding::ASCII == key.encoding }
        And { 40 == key.size }
        And { CZTop::Z85.new.encode(cert.public_key(format: :binary)) == key }
      end

      context "with no format" do
        let(:key) { cert.public_key }
        Then { cert.public_key(format: :z85) == key } # same as with no format
      end

      context "with :binary format" do
        Given(:key) { cert.public_key(format: :binary) }
        Then { Encoding::BINARY == key.encoding }
        And { 32 == key.bytesize }
      end

      context "with invalid format" do
        When(:result) { cert.public_key(format: :foo) }
        Then { result == Failure(ArgumentError) }
      end
    end

    describe "#secret_key" do
      context "with :z85 format" do
        Given(:key) { cert.secret_key(format: :z85) }
        Then { Encoding::ASCII == key.encoding }
        And { 40 == key.size }
        And { CZTop::Z85.new.encode(cert.secret_key(format: :binary)) == key }
      end
      context "with no format" do
        let(:key) { cert.secret_key }
        Then { cert.secret_key(format: :z85) == key } # same as with no format
      end
      context "with :binary format" do
        Given(:key) { cert.secret_key(format: :binary) }
        Then { Encoding::BINARY == key.encoding }
        And { 32 == key.bytesize }
      end
      context "with undefined secret key" do
        # NOTE: this happens when cert was loaded from file created with
        # #save_public
        let(:undefined_z85) { "0" * 40 }
        let(:undefined_bin) { "\0" * 32 }
        let(:pointer_z85) { double(read_string: undefined_z85) }
        let(:pointer_bin) { double(read_string: undefined_bin) }
        before(:each) do
          expect(ffi_delegate).to(receive(:secret_txt).and_return(pointer_z85))
          expect(ffi_delegate).to(receive(:secret_key).and_return(pointer_bin))
        end
        it "returns nil" do
          assert_nil cert.secret_key(format: :z85)
          assert_nil cert.secret_key(format: :binary)
        end
      end
      context "with invalid format" do
        When(:result) { cert.secret_key(format: :foo) }
        Then { result == Failure(ArgumentError) }
      end
    end

    describe "meta information" do
      Given(:key) { "foo" }
      Given(:value) { "bar" }
      describe "#meta" do
        context "with existing meta key" do
          Given { cert[key] = value }
          Then { cert[key] == value }
        end
        context "with non-existing meta key" do
          Then { cert[key].nil? }
        end
      end

      describe "#meta=" do
        context "when setting" do
          it "sets" do
            expect(ffi_delegate).to(
              receive(:set_meta).with(key, String, :string, value))
            cert[key] = value
          end
        end
        context "when unsetting" do
          Given { cert[key] = value }
          When { cert[key] = nil }
          Then { cert[key].nil? }
        end
        it "does safe format handling" do
          expect(ffi_delegate).to receive(:set_meta).with(String, "%s", any_args)
          cert[key] = value
        end
      end

      describe "#meta_keys" do
        context "with meta keys set" do
          let(:values) { { "key1" => "value1", "key2" => "value2" } }
          before(:each) do
            values.each {|k,v| cert[k] = v }
          end
          it "returns keys" do
            assert_equal values.keys.sort, cert.meta_keys.sort
          end
        end
        context "with no meta keys set" do
          it "returns empty array" do
            assert_equal [], cert.meta_keys
          end
        end
      end

      describe "#dup" do
        When(:duplicate_cert) { cert.dup }
        Then { cert == duplicate_cert }

        context "with failure" do
          it "raises" do
            expect(cert.ffi_delegate).to(
            receive(:dup).and_return(::FFI::Pointer::NULL))
            assert_raises(SystemCallError) { cert.dup }
          end
        end
      end

      describe ".check_curve_availability" do
        context "with CURVE available" do
          before(:each) do
            expect(::CZMQ::FFI::Zproc).to receive(:has_curve).and_return(true)
          end
          it "doesn't warn" do
            assert_output("", "") do
              described_class.check_curve_availability
            end
          end
        end
        context "with CURVE not available" do
          before(:each) do
            expect(::CZMQ::FFI::Zproc).to receive(:has_curve).and_return(false)
          end
          it "warns" do
            assert_output("", /curve.*libsodium/i) do
              described_class.check_curve_availability
            end
          end
        end
      end

      describe ".new_from" do
        Given(:public_key) { cert.public_key(format: :binary) }
        Given(:secret_key) { cert.secret_key(format: :binary) }
        When(:new_cert) do
          CZTop::Certificate.new_from(public_key, secret_key)
        end
        Then { cert == new_cert && new_cert == cert }
        context "with invalid public key size" do
          Given(:public_key) { "too short" }
          Then { new_cert == Failure(ArgumentError) }
        end
        context "with invalid secret key size" do
          Given(:secret_key) { "too short" }
          Then { new_cert == Failure(ArgumentError) }
        end
        context "with missing public key" do
          Given(:public_key) { nil }
          Then { new_cert == Failure(ArgumentError) }
        end
        context "with missing secret key" do
          Given(:secret_key) { nil }
          Then { new_cert == Failure(ArgumentError) }
        end
      end

      describe "#==" do
        context "with equal certificate" do
          Given(:other) { cert.dup }
          Then { cert  == other }
          And  { other == cert  }
        end
        context "with different certificate" do
          Given(:other) { CZTop::Certificate.new }
          Then { cert  != other }
          And  { other != cert  }
        end
      end

      describe "#apply" do
        let(:zocket) { double("zocket") }

        it "applies to socket" do
          expect(ffi_delegate).to(receive(:apply).with(zocket))
          cert.apply(zocket)
        end

        context "with undefined secret key" do
          before(:each) do
            expect(cert).to(receive(:secret_key).and_return(nil))
          end
          it "raises" do
            assert_raises(SystemCallError) do
              cert.apply(zocket)
            end
          end
        end

        context "with invalid socket" do
          let(:zocket) { nil }
          it "raises" do
            assert_raises(ArgumentError) { cert.apply(zocket) }
          end
        end

        context "with real socket" do
          let(:zocket) { CZTop::Socket::REQ.new }
          it "works" do
            cert.apply(zocket)
          end
        end
      end
    end

    describe "serialization" do
      let(:tmpdir) do
        Pathname.new(Dir.mktmpdir("zcert_test"))
      end
      let(:path) { tmpdir + "zcert.txt" }

      describe "#save" do
        When(:result) { cert.save(path) }
        context "with valid path" do
          Given { !path.exist? }
          Then { path.exist? }
        end
        context "with invalid path" do
          Given(:path) { "/" }
          Then { result == Failure(SystemCallError) }
        end
        context "with empty path" do
          Given(:path) { "" }
          Then { result == Failure(ArgumentError) }
        end
      end

      describe "#save_public" do
        When(:result) { cert.save_public(path) }
        context "with valid path" do
          Given { !path.exist? }
          Then { path.exist? }
        end
        context "with invalid path" do
          Given(:path) { "/" }
          Then { result == Failure(SystemCallError) }
        end
        context "reading such a file" do
          Given { cert.save_public(path) }
          Given(:loaded_cert) { CZTop::Certificate.load(path) }
          Then { loaded_cert.secret_key.nil? }
          And { loaded_cert.public_key }
        end
      end
      describe "#save_secret" do
        When(:result) { cert.save_secret(path) }
        context "with valid path" do
          Given { !path.exist? }
          Then { path.exist? }
        end
        context "with invalid path" do
          Given(:path) { "/" }
          Then { result == Failure(SystemCallError) }
        end
      end

      describe ".load" do
        context "with existing file" do
          before(:each) { cert.save(path) }
          let(:loaded_cert) { CZTop::Certificate.load(path) }
          it "loads the certificate" do
            assert_kind_of CZTop::Certificate, loaded_cert
            assert_equal cert, loaded_cert
          end
        end
        context "with non-existing file" do
          it "raises" do
            assert_raises do
              CZTop::Certificate.load("/does/not/exist")
            end
          end
        end
      end
    end
  end
end
