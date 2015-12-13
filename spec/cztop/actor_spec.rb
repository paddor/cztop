require_relative 'spec_helper'

describe CZTop::Actor do
  include_examples "has FFI delegate"

  it "has Zsock options" do
    assert_operator described_class, :<, CZTop::ZsockOptions
  end

  it "has send/receive methods" do
    assert_operator described_class, :<, CZTop::SendReceiveMethods
  end

  it "has polymorphic Zsock methods" do
    assert_operator described_class, :<, CZTop::PolymorphicZsockMethods
  end

  it "instanciates" do
    described_class.new
  end

  let(:actor) { CZTop::Actor.new }
  let(:cmd) { %w[SHOW] }
  let(:msg) { CZTop::Message.new(cmd) }
  it "receives commands" do
    actor << msg
  end
end
