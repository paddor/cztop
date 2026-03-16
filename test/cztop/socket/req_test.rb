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


  describe 'reconnection (tcp)' do
    it 'resumes after REP restarts (clean cycle)' do
      rep = CZTop::Socket::REP.new
      rep.send_timeout = 0.1
      rep.recv_timeout = 0.1
      rep.linger = 0
      rep.bind('tcp://127.0.0.1:*')
      port = rep.last_tcp_port

      req = CZTop::Socket::REQ.new
      req.send_timeout = 0.5
      req.recv_timeout = 0.5
      req.linger = 0
      req.reconnect_ivl = 0.01
      req.connect("tcp://127.0.0.1:#{port}")

      # First round-trip
      req << 'hello'
      assert_equal ['hello'], rep.receive
      rep << 'world'
      assert_equal ['world'], req.receive

      # Restart REP on same port
      rep.close
      sleep 0.2 # allow OS to release port

      rep2 = CZTop::Socket::REP.new
      rep2.send_timeout = 0.5
      rep2.recv_timeout = 0.5
      rep2.linger = 0
      rep2.bind("tcp://127.0.0.1:#{port}")
      sleep 0.2 # allow REQ to reconnect

      # Second round-trip
      req << 'hello again'
      assert_equal ['hello again'], rep2.receive
      rep2 << 'welcome back'
      assert_equal ['welcome back'], req.receive
    end


    it 'REQ gets stuck when REP dies mid-cycle' do
      rep = CZTop::Socket::REP.new
      rep.send_timeout = 0.1
      rep.recv_timeout = 0.1
      rep.linger = 0
      rep.bind('tcp://127.0.0.1:*')
      port = rep.last_tcp_port

      req = CZTop::Socket::REQ.new
      req.send_timeout = 0.1
      req.recv_timeout = 0.2
      req.linger = 0
      req.connect("tcp://127.0.0.1:#{port}")

      # REQ sends, REP receives but dies before replying
      req << 'request'
      rep.receive
      rep.close

      # REQ is stuck in recv state — times out
      assert_raises(IO::TimeoutError) { req.receive }
    end
  end
end
