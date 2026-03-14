# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::REQ do
  describe 'integration' do
    let(:req) { CZTop::Socket::REQ.new }
    let(:rep) { CZTop::Socket::REP.new }
    i = 0
    let(:endpoint) { "inproc://req_test_#{i += 1}" }

    before do
      req.send_timeout = 0.1
      req.recv_timeout = 0.1
      rep.send_timeout = 0.1
      rep.recv_timeout = 0.1

      rep.bind endpoint
      req.connect endpoint
    end


    it 'performs a REQ/REP round-trip' do
      req << 'hello'
      msg = rep.receive
      assert_equal ['hello'], msg

      rep << 'world'
      msg = req.receive
      assert_equal ['world'], msg
    end


    it 'sends and receives multipart messages' do
      req << %w[part1 part2 part3]
      msg = rep.receive
      assert_equal %w[part1 part2 part3], msg

      rep << %w[reply1 reply2]
      msg = req.receive
      assert_equal %w[reply1 reply2], msg
    end


    it 'handles empty string frames' do
      req << ['', 'data', '']
      msg = rep.receive
      assert_equal ['', 'data', ''], msg

      rep << 'ok'
      req.receive
    end


    it 'performs multiple round-trips in sequence' do
      5.times do |n|
        req << "request_#{n}"
        msg = rep.receive
        assert_equal ["request_#{n}"], msg

        rep << "reply_#{n}"
        msg = req.receive
        assert_equal ["reply_#{n}"], msg
      end
    end
  end
end
