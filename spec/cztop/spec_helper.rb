require_relative '../spec_helper'

RSpec.shared_examples "has FFI delegate" do
  it "has an FFI delegate" do
    assert_operator described_class, :<, CZTop::HasFFIDelegate
    assert_kind_of CZTop::HasFFIDelegate::ClassMethods, described_class
  end
end
