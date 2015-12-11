require_relative '../../spec_helper'

describe CZTop::Message::FramesAccessor do
  context "new Message" do
    subject { CZTop::Message.new }

    it "has no frames" do
      assert_equal 0, subject.size
    end
  end

  # TODO
end
