# frozen_string_literal: true

require_relative '../test_helper'

describe CZTop::Socket::REP do
  describe 'integration' do
    let(:rep) { CZTop::Socket::REP.new }
    let(:req) { CZTop::Socket::REQ.new }
    i = 0
    let(:endpoint) { "inproc://rep_test_#{i += 1}" }

    before do
      rep.send_timeout = 0.1
      rep.recv_timeout = 0.1
      req.send_timeout = 0.1
      req.recv_timeout = 0.1

      rep.bind endpoint
      req.connect endpoint
    end


    it 'binds and echoes back a single message' do
      req << 'ping'
      msg = rep.receive
      assert_equal ['ping'], msg

      rep << msg.first
      reply = req.receive
      assert_equal ['ping'], reply
    end


    it 'echoes back multipart messages' do
      req << %w[multi part echo]
      msg = rep.receive
      assert_equal %w[multi part echo], msg

      rep << msg
      reply = req.receive
      assert_equal %w[multi part echo], reply
    end


    it 'handles multiple sequential echo exchanges' do
      3.times do |n|
        req << "echo_#{n}"
        msg = rep.receive
        rep << msg.first.upcase
        reply = req.receive
        assert_equal ["ECHO_#{n}"], reply
      end
    end
  end
end
