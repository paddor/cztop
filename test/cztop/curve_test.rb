# frozen_string_literal: true

require_relative 'test_helper'


describe CZTop::CURVE do

  describe '.available?' do
    it 'returns a boolean' do
      assert_includes [true, false], CZTop::CURVE.available?
    end
  end


  describe '.keypair' do
    before { skip unless CZTop::CURVE.available? }

    it 'returns two 32-byte binary strings' do
      pub, sec = CZTop::CURVE.keypair
      assert_equal 32, pub.bytesize
      assert_equal 32, sec.bytesize
      assert_equal Encoding::ASCII_8BIT, pub.encoding
      assert_equal Encoding::ASCII_8BIT, sec.encoding
    end

    it 'returns different keys each time' do
      _, sec1 = CZTop::CURVE.keypair
      _, sec2 = CZTop::CURVE.keypair
      refute_equal sec1, sec2
    end
  end


  describe '.public_key' do
    before { skip unless CZTop::CURVE.available? }

    it 'derives the correct public key from a secret key' do
      pub, sec = CZTop::CURVE.keypair
      derived = CZTop::CURVE.public_key(sec)
      assert_equal pub, derived
    end

    it 'raises ArgumentError for wrong key size' do
      assert_raises(ArgumentError) { CZTop::CURVE.public_key('too_short') }
    end
  end


  describe '.z85_encode / .z85_decode' do
    it 'round-trips binary data' do
      binary = ("\x00" * 4 + "\xff" * 4 + "\xab\xcd\xef\x01").b
      z85 = CZTop::CURVE.z85_encode(binary)
      assert_kind_of String, z85
      assert_equal binary, CZTop::CURVE.z85_decode(z85)
    end

    it 'round-trips a 32-byte key' do
      skip unless CZTop::CURVE.available?
      pub, _ = CZTop::CURVE.keypair
      z85 = CZTop::CURVE.z85_encode(pub)
      assert_equal 40, z85.bytesize
      assert_equal pub, CZTop::CURVE.z85_decode(z85)
    end

    it 'raises for binary not divisible by 4' do
      assert_raises(ArgumentError) { CZTop::CURVE.z85_encode('abc') }
    end

    it 'raises for Z85 not divisible by 5' do
      assert_raises(ArgumentError) { CZTop::CURVE.z85_decode('abcd') }
    end
  end

end
