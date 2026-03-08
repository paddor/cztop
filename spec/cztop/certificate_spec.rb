# frozen_string_literal: true

require_relative 'spec_helper'
require 'tmpdir'
require 'pathname'

unless ::CZMQ::FFI::Zsys.has_curve
  warn "Skipping most CZTop::Certificate specs because CURVE is not available."
end


describe CZTop::Certificate do
  before { skip 'CURVE is available' if ::CZMQ::FFI::Zsys.has_curve }

  describe '#initialize' do
    it 'raises' do
      assert_raises(NotImplementedError) do
        CZTop::Certificate.new
      end
    end
  end
end


describe CZTop::Certificate do
  include HasFFIDelegateExamples
  include ZMQHelper

  before { skip 'requires CURVE' unless ::CZMQ::FFI::Zsys.has_curve }

  describe 'with certificate' do
    let(:cert) { CZTop::Certificate.new }
    let(:ffi_delegate) { cert.ffi_delegate }

    describe '#initialize' do
      it 'creates a valid certificate' do
        assert cert
        refute cert.zero?
      end
    end

    describe '#public_key' do
      describe 'with :z85 format' do
        it 'returns ASCII encoded 40-char key matching binary encoding' do
          key = cert.public_key(format: :z85)
          assert_equal Encoding::ASCII, key.encoding
          assert_equal 40, key.size
          assert_equal CZTop::Z85.new.encode(cert.public_key(format: :binary)), key
        end
      end

      describe 'with no format' do
        it 'returns same as z85 format' do
          assert_equal cert.public_key(format: :z85), cert.public_key
        end
      end

      describe 'with :binary format' do
        it 'returns binary encoded 32-byte key' do
          key = cert.public_key(format: :binary)
          assert_equal Encoding::BINARY, key.encoding
          assert_equal 32, key.bytesize
        end
      end

      describe 'with invalid format' do
        it 'raises' do
          assert_raises(ArgumentError) { cert.public_key(format: :foo) }
        end
      end
    end

    describe '#secret_key' do
      describe 'with :z85 format' do
        it 'returns ASCII encoded 40-char key matching binary encoding' do
          key = cert.secret_key(format: :z85)
          assert_equal Encoding::ASCII, key.encoding
          assert_equal 40, key.size
          assert_equal CZTop::Z85.new.encode(cert.secret_key(format: :binary)), key
        end
      end

      describe 'with no format' do
        it 'returns same as z85 format' do
          assert_equal cert.secret_key(format: :z85), cert.secret_key
        end
      end

      describe 'with :binary format' do
        it 'returns binary encoded 32-byte key' do
          key = cert.secret_key(format: :binary)
          assert_equal Encoding::BINARY, key.encoding
          assert_equal 32, key.bytesize
        end
      end

      describe 'with undefined secret key' do
        # NOTE: this happens when cert was loaded from file created with
        # #save_public
        it 'returns nil' do
          undefined_z85 = '0' * 40
          undefined_bin = "\0" * 32
          pointer_bin = Object.new
          pointer_bin.define_singleton_method(:read_string) { |*| undefined_bin }

          ffi_delegate.stub(:secret_txt, undefined_z85) do
            ffi_delegate.stub(:secret_key, pointer_bin) do
              assert_nil cert.secret_key(format: :z85)
              assert_nil cert.secret_key(format: :binary)
            end
          end
        end
      end

      describe 'with invalid format' do
        it 'raises' do
          assert_raises(ArgumentError) { cert.secret_key(format: :foo) }
        end
      end
    end

    describe 'meta information' do
      let(:key) { 'foo' }
      let(:val) { 'bar' }

      describe '#meta' do
        describe 'with existing meta key' do
          it 'returns the val' do
            cert[key] = val
            assert_equal val, cert[key]
          end
        end
        describe 'with non-existing meta key' do
          it 'returns nil' do
            assert_nil cert[key]
          end
        end
      end

      describe '#meta=' do
        describe 'when setting' do
          it 'calls set_meta with correct args' do
            called_with = nil
            ffi_delegate.stub(:set_meta, ->(*args) { called_with = args }) do
              cert[key] = val
            end
            assert_kind_of String, called_with[0]
            assert_equal :string, called_with[2]
            assert_equal val, called_with[3]
          end
        end

        describe 'when unsetting' do
          before { skip 'requires CZMQ drafts and CURVE' unless has_czmq_drafts? && ::CZMQ::FFI::Zsys.has_curve }
          it 'unsets the meta val' do
            cert[key] = val
            cert[key] = nil
            assert_nil cert[key]
          end
        end

        it 'does safe format handling' do
          called_with = nil
          ffi_delegate.stub(:set_meta, ->(*args) { called_with = args }) do
            cert[key] = val
          end
          assert_equal '%s', called_with[1]
        end
      end

      describe '#meta_keys' do
        describe 'with meta keys set' do
          let(:values) { { 'key1' => 'value1', 'key2' => 'value2' } }
          before do
            values.each { |k, v| cert[k] = v }
          end
          it 'returns keys' do
            assert_equal values.keys.sort, cert.meta_keys.sort
          end
        end
        describe 'with no meta keys set' do
          it 'returns empty array' do
            assert_equal [], cert.meta_keys
          end
        end
      end

      describe '#dup' do
        it 'creates equal duplicate' do
          assert_equal cert, cert.dup
        end

        describe 'with failure' do
          it 'raises' do
            cert.ffi_delegate.stub(:dup, ::FFI::Pointer::NULL) do
              assert_raises(SystemCallError) { cert.dup }
            end
          end
        end
      end

      describe '.check_curve_availability' do
        describe 'with CURVE available' do
          it "doesn't warn" do
            ::CZMQ::FFI::Zsys.stub(:has_curve, true) do
              assert_output('', '') do
                CZTop::Certificate.check_curve_availability
              end
            end
          end
        end
        describe 'with CURVE not available' do
          it 'warns' do
            ::CZMQ::FFI::Zsys.stub(:has_curve, false) do
              assert_output('', /curve.*libsodium/i) do
                CZTop::Certificate.check_curve_availability
              end
            end
          end
        end
      end

      describe '.new_from' do
        let(:public_key) { cert.public_key(format: :binary) }
        let(:secret_key) { cert.secret_key(format: :binary) }

        describe 'with valid binary key pair' do
          it 'creates equal certificate' do
            new_cert = CZTop::Certificate.new_from(public_key, secret_key)
            assert_equal cert, new_cert
            assert_equal new_cert, cert
          end
        end

        describe 'with valid Z85 (text) key pair' do
          let(:public_key) { cert.public_key(format: :z85) }
          let(:secret_key) { cert.secret_key(format: :z85) }
          it 'creates equal certificate' do
            new_cert = CZTop::Certificate.new_from(public_key, secret_key)
            assert_equal cert, new_cert
            assert_equal new_cert, cert
          end
        end

        describe 'with invalid public key size' do
          let(:public_key) { 'too short' }
          it 'raises' do
            assert_raises(ArgumentError) { CZTop::Certificate.new_from(public_key, secret_key) }
          end
        end

        describe 'with invalid secret key size' do
          let(:secret_key) { 'too short' }
          it 'raises' do
            assert_raises(ArgumentError) { CZTop::Certificate.new_from(public_key, secret_key) }
          end
        end

        describe 'with missing public key' do
          let(:public_key) { nil }
          it 'raises' do
            assert_raises(ArgumentError) { CZTop::Certificate.new_from(public_key, secret_key) }
          end
        end

        describe 'with missing secret key' do
          # public key only certificate, should work
          let(:secret_key) { nil }
          it 'creates cert with matching public key' do
            new_cert = CZTop::Certificate.new_from(public_key, secret_key)
            assert_equal cert.public_key, new_cert.public_key
          end
        end
      end

      describe '#==' do
        describe 'with equal certificate' do
          it 'is equal' do
            other = cert.dup
            assert_operator cert, :==, other
            assert_operator other, :==, cert
          end
        end
        describe 'with different certificate' do
          it 'is not equal' do
            other = CZTop::Certificate.new
            refute_operator cert, :==, other
            refute_operator other, :==, cert
          end
        end
      end

      describe '#apply' do
        let(:zocket) { Object.new }

        it 'applies to socket' do
          called_with = nil
          ffi_delegate.stub(:apply, ->(z) { called_with = z }) do
            cert.apply(zocket)
          end
          assert_same zocket, called_with
        end

        describe 'with undefined secret key' do
          it 'raises' do
            cert.stub(:secret_key, nil) do
              assert_raises(SystemCallError) do
                cert.apply(zocket)
              end
            end
          end
        end

        describe 'with invalid socket' do
          let(:zocket) { nil }
          it 'raises' do
            assert_raises(ArgumentError) { cert.apply(zocket) }
          end
        end

        describe 'with real socket' do
          let(:zocket) { CZTop::Socket::REQ.new }
          it 'works' do
            cert.apply(zocket)
          end
        end
      end
    end

    describe 'serialization' do
      let(:tmpdir) do
        Pathname.new(Dir.mktmpdir('zcert_test'))
      end
      let(:path) { tmpdir + 'zcert.txt' }

      describe '#save' do
        describe 'with valid path' do
          it 'creates the file' do
            refute path.exist?
            cert.save(path)
            assert path.exist?
          end
        end
        describe 'with invalid path' do
          let(:path) { '/' }
          it 'raises' do
            assert_raises(SystemCallError) { cert.save(path) }
          end
        end
        describe 'with empty path' do
          let(:path) { '' }
          it 'raises' do
            assert_raises(ArgumentError) { cert.save(path) }
          end
        end
      end

      describe '#save_public' do
        describe 'with valid path' do
          it 'creates the file' do
            refute path.exist?
            cert.save_public(path)
            assert path.exist?
          end
        end
        describe 'with invalid path' do
          let(:path) { '/' }
          it 'raises' do
            assert_raises(SystemCallError) { cert.save_public(path) }
          end
        end
        describe 'reading such a file' do
          it 'has no secret key but has public key' do
            cert.save_public(path)
            loaded_cert = CZTop::Certificate.load(path)
            assert_nil loaded_cert.secret_key
            assert loaded_cert.public_key
          end
        end
      end

      describe '#save_secret' do
        describe 'with valid path' do
          it 'creates the file' do
            refute path.exist?
            cert.save_secret(path)
            assert path.exist?
          end
        end
        describe 'with invalid path' do
          let(:path) { '/' }
          it 'raises' do
            assert_raises(SystemCallError) { cert.save_secret(path) }
          end
        end
      end

      describe '.load' do
        describe 'with existing file' do
          before { cert.save(path) }
          let(:loaded_cert) { CZTop::Certificate.load(path) }
          it 'loads the certificate' do
            assert_kind_of CZTop::Certificate, loaded_cert
            assert_equal cert, loaded_cert
          end
        end
        describe 'with non-existing file' do
          it 'raises' do
            assert_raises(Errno::ENOENT) do
              CZTop::Certificate.load('/does/not/exist')
            end
          end
        end
      end
    end
  end
end
