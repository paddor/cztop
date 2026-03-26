# frozen_string_literal: true

require_relative '../test_helper'

describe 'IPC transport' do
  describe 'abstract namespace' do
    i = 0
    let(:endpoint) { "ipc://@cztop_abstract_test_#{i += 1}" }

    it 'sends and receives via abstract namespace' do
      rep = CZTop::Socket::REP.new
      rep.send_timeout = 0.5
      rep.recv_timeout = 0.5
      rep.bind endpoint

      req = CZTop::Socket::REQ.new
      req.send_timeout = 0.5
      req.recv_timeout = 0.5
      req.connect endpoint

      req << 'ping'
      msg = rep.receive
      assert_equal ['ping'], msg

      rep << 'pong'
      msg = req.receive
      assert_equal ['pong'], msg
    end


    it 'leaves no socket file on disk' do
      pair_a = CZTop::Socket::PAIR.new
      pair_a.bind endpoint

      # Abstract namespace sockets have no filesystem entry
      refute File.exist?(endpoint.sub('ipc://@', ''))
      refute File.exist?("@cztop_abstract_test_#{i}")
    end


    it 'supports PUB/SUB over abstract namespace' do
      pub = CZTop::Socket::PUB.new
      pub.send_timeout = 0.5
      pub.bind endpoint

      sub = CZTop::Socket::SUB.new
      sub.recv_timeout = 0.5
      sub.subscribe
      sub.connect endpoint
      sleep 0.05

      pub << 'abstract broadcast'
      msg = sub.receive
      assert_equal ['abstract broadcast'], msg
    end


    it 'supports PUSH/PULL over abstract namespace' do
      pull = CZTop::Socket::PULL.new
      pull.recv_timeout = 0.5
      pull.bind endpoint

      push = CZTop::Socket::PUSH.new
      push.send_timeout = 0.5
      push.connect endpoint

      push << 'abstract pipeline'
      msg = pull.receive
      assert_equal ['abstract pipeline'], msg
    end


    it 'supports multipart messages' do
      rep = CZTop::Socket::REP.new
      rep.send_timeout = 0.5
      rep.recv_timeout = 0.5
      rep.bind endpoint

      req = CZTop::Socket::REQ.new
      req.send_timeout = 0.5
      req.recv_timeout = 0.5
      req.connect endpoint

      req << %w[hello abstract world]
      msg = rep.receive
      assert_equal %w[hello abstract world], msg
    end
  end
end
