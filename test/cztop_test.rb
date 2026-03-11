# frozen_string_literal: true

require_relative 'test_helper'

describe CZTop do
  it 'has a version' do
    refute_nil CZTop::VERSION
  end

  it "disables CZMQ's default signal handling" do
    assert CZMQ::FFI::Signals.default_handling_disabled?
  end
end
