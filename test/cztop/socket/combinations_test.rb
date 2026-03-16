# frozen_string_literal: true

require_relative '../test_helper'


describe 'socket combinations' do
  describe 'ROUTER + REQ' do
    i = 0
    let(:endpoint) { "inproc://combo_router_req_#{i += 1}" }

    let(:router) do
      CZTop::Socket::ROUTER.new.tap do |r|
        r.send_timeout = 0.1
        r.recv_timeout = 0.1
        r.bind endpoint
      end
    end

    let(:req) do
      CZTop::Socket::REQ.new.tap do |r|
        r.send_timeout = 0.1
        r.recv_timeout = 0.1
        r.identity = 'test_req'
        r.connect endpoint
      end
    end

    before do
      router
      req
      sleep 0.05
    end


    it 'performs a round-trip via identity routing' do
      req << 'hello'
      msg = router.receive
      assert_equal ['test_req', '', 'hello'], msg

      router.send_to('test_req', 'world')
      msg = req.receive
      assert_equal ['world'], msg
    end


    it 'routes multiple REQ clients by identity' do
      req2 = CZTop::Socket::REQ.new
      req2.send_timeout = 0.1
      req2.recv_timeout = 0.1
      req2.identity = 'test_req2'
      req2.connect endpoint
      sleep 0.05

      req << 'from_req1'
      req2 << 'from_req2'

      msgs = {}
      2.times do
        msg = router.receive
        msgs[msg.first] = msg.last
      end

      assert_equal 'from_req1', msgs['test_req']
      assert_equal 'from_req2', msgs['test_req2']

      router.send_to('test_req', 'reply1')
      router.send_to('test_req2', 'reply2')

      assert_equal ['reply1'], req.receive
      assert_equal ['reply2'], req2.receive
    end
  end


  describe 'ROUTER + ROUTER' do
    i = 0
    let(:endpoint) { "inproc://combo_router_router_#{i += 1}" }

    let(:router_a) do
      CZTop::Socket::ROUTER.new.tap do |r|
        r.identity = 'A'
        r.send_timeout = 0.1
        r.recv_timeout = 0.1
        r.bind endpoint
      end
    end

    let(:router_b) do
      CZTop::Socket::ROUTER.new.tap do |r|
        r.identity = 'B'
        r.send_timeout = 0.1
        r.recv_timeout = 0.1
        r.connect endpoint
      end
    end

    before do
      router_a
      router_b
      sleep 0.05
    end


    it 'exchanges messages bidirectionally using ZMTP identities' do
      router_b.send(['A', '', 'ping'])
      msg = router_a.receive
      assert_equal ['B', '', 'ping'], msg

      router_a.send(['B', '', 'pong'])
      msg = router_b.receive
      assert_equal ['A', '', 'pong'], msg
    end
  end


  describe 'two-step pipeline (fan-out / fan-in)' do
    i = 0
    let(:vent_ep) { "inproc://combo_pipeline_vent_#{i += 1}" }
    let(:coll_ep) { "inproc://combo_pipeline_coll_#{i}" }

    it 'fans out tasks to workers and collects results' do
      ventilator = CZTop::Socket::PUSH.new
      ventilator.send_timeout = 0.5
      ventilator.bind vent_ep

      collector = CZTop::Socket::PULL.new
      collector.recv_timeout = 2
      collector.bind coll_ep

      workers = 3.times.map do
        Thread.new do
          pull = CZTop::Socket::PULL.new
          pull.recv_timeout = 0.5
          pull.connect vent_ep

          push = CZTop::Socket::PUSH.new
          push.send_timeout = 0.5
          push.connect coll_ep

          loop do
            msg = pull.receive
            push << msg.first.upcase
          rescue IO::TimeoutError, IO::EAGAINWaitReadable
            break
          end
        end
      end

      sleep 0.05

      9.times { |n| ventilator << "task_#{n}" }

      results = []
      9.times do
        msg = collector.receive
        results << msg.first
      end

      assert_equal 9, results.size
      assert_equal 9.times.map { |n| "TASK_#{n}" }.sort, results.sort

      workers.each(&:join)
    end
  end


  describe 'XPUB with multiple SUB' do
    i = 0
    let(:endpoint) { "inproc://combo_xpub_multi_sub_#{i += 1}" }

    let(:xpub) do
      CZTop::Socket::XPUB.new.tap do |s|
        s.send_timeout = 0.1
        s.recv_timeout = 0.1
        s.bind endpoint
      end
    end


    it 'routes messages by topic to correct subscribers' do
      xpub

      sub_a = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub_a.recv_timeout = 0.1
      sub_a.subscribe('news')
      sub_a.connect endpoint

      sub_b = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub_b.recv_timeout = 0.1
      sub_b.subscribe('news')
      sub_b.connect endpoint

      sub_c = CZTop::Socket::SUB.new(nil, prefix: nil)
      sub_c.recv_timeout = 0.1
      sub_c.subscribe('sports')
      sub_c.connect endpoint

      sleep 0.05

      # XPUB deduplicates subscriptions by default:
      # "news" (from sub_a) + "sports" (from sub_c) = 2 unique events
      2.times { xpub.receive }

      xpub << 'news flash'
      assert_equal ['news flash'], sub_a.receive
      assert_equal ['news flash'], sub_b.receive
      assert_raises(IO::TimeoutError) { sub_c.receive }

      xpub << 'sports update'
      assert_equal ['sports update'], sub_c.receive
      assert_raises(IO::TimeoutError) { sub_a.receive }
      assert_raises(IO::TimeoutError) { sub_b.receive }
    end
  end
end
