# frozen_string_literal: true

require_relative '../test_helper'

module HasFFIDelegateExamples

  def test_has_ffi_delegate
    klass = self.class::SUBJECT
    assert_operator klass, :<, CZTop::HasFFIDelegate
    assert_kind_of CZTop::HasFFIDelegate::ClassMethods, klass
  end
end
