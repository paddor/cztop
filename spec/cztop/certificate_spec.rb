require_relative 'spec_helper'
require 'tmpdir'
require 'pathname'

describe CZTop::Certificate do
  include_examples "has FFI delegate"

  context "with certificate" do
    let(:cert) { CZTop::Certificate.new }
    let(:ffi_delegate) { cert.ffi_delegate }
    describe "#initialize" do
      it "initializes" do
        cert
      end
    end

    describe "#public_key" do
      let(:key) { cert.public_key }
      it "returns key" do
        assert_kind_of String, key
      end
      it "is binary" do
        assert_equal Encoding::BINARY, key.encoding
      end
      it "has correct length" do
        assert_equal 32, key.bytesize
      end
    end

    describe "#secret_key" do
      let(:key) { cert.secret_key }
      it "returns key" do
        assert_kind_of String, key
      end
      it "is binary" do
        assert_equal Encoding::BINARY, key.encoding
      end
      it "has correct length" do
        assert_equal 32, key.bytesize
      end
      context "with undefined secret key" do
        # NOTE: this happens when cert was loaded from file created with
        # #save_public
        let(:undefined_key) { "\0" * 32 }
        let(:pointer) { double(read_string: undefined_key) }
        before(:each) do
          expect(ffi_delegate).to(receive(:secret_key).and_return(pointer))
        end
        it "returns nil" do
          assert_nil cert.secret_key
        end
      end
    end

    describe "#public_key_txt" do
      let(:key) { cert.public_key_txt }
      it "returns key" do
        assert_kind_of String, key
      end
      it "is ASCII" do
        assert_equal Encoding::ASCII, key.encoding
      end
      it "has correct length" do
        assert_equal 40, key.size
      end
      it "is Z85 and correct" do
        assert_equal cert.public_key, CZTop::Z85.new.decode(key)
      end
    end

    describe "#secret_key_txt" do
      let(:key) { cert.secret_key_txt }
      it "returns key" do
        assert_kind_of String, key
      end
      it "is ASCII" do
        assert_equal Encoding::ASCII, key.encoding
      end
      it "has correct length" do
        assert_equal 40, key.size
      end
      it "is Z85 and correct" do
        assert_equal cert.secret_key, CZTop::Z85.new.decode(key)
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
        context "when unsetting", skip: true do
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
            assert_raises(CZTop::Certificate::Error) { cert.dup }
          end
        end
      end

      describe ".new_from" do
        Given(:public_key) { cert.public_key }
        Given(:secret_key) { cert.secret_key }
        When(:new_cert) do
          CZTop::Certificate.new_from(public_key, secret_key)
        end
        Then { cert == new_cert && new_cert == cert }
        context "with invalid public key size" do
          Given(:public_key) { "too short" }
          Then { new_cert == Failure(CZTop::Certificate::Error) }
        end
        context "with invalid secret key size" do
          Given(:secret_key) { "too short" }
          Then { new_cert == Failure(CZTop::Certificate::Error) }
        end
        context "with missing public key" do
          Given(:public_key) { nil }
          Then { new_cert == Failure(CZTop::Certificate::Error) }
        end
        context "with missing secret key" do
          Given(:secret_key) { nil }
          Then { new_cert == Failure(CZTop::Certificate::Error) }
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
            assert_raises(CZTop::Certificate::Error) do
              cert.apply(zocket)
            end
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
          Then { result == Failure(CZTop::Certificate::Error) }
        end
        context "with empty path" do
          Given(:path) { "" }
          Then { result == Failure(CZTop::Certificate::Error) }
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
          Then { result == Failure(CZTop::Certificate::Error) }
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
          Then { result == Failure(CZTop::Certificate::Error) }
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
