#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))

require 'minitest/autorun'
require 'minitest/spec'
require 'cztop'

# ZGuide Chapter 4 — Binary Star Pattern
# Active/passive high-availability pair. The primary server handles
# client requests while exchanging heartbeats with a backup. When the
# primary fails, the backup detects the loss via heartbeat timeout and
# takes over. The client retries against the backup on timeout.
#
# Fencing rule: backup only takes over if heartbeats are lost (proving
# the primary is truly gone, not just a network partition between them).

describe 'Binary Star' do
  it 'backup takes over when primary fails' do
    primary_ep = 'inproc://zg10_primary'
    backup_ep  = 'inproc://zg10_backup'
    hb_ep      = 'inproc://zg10_heartbeat'
    served_by  = []

    # Heartbeat publisher (primary → backup)
    hb_thread = Thread.new do
      pub = Cztop::Socket::PUB.bind(hb_ep)
      sleep 0.01
      loop do
        pub << 'HB'
        sleep 0.05
      rescue IOError
        break
      end
    end

    # Primary server
    primary_thread = Thread.new do
      rep = Cztop::Socket::REP.bind(primary_ep)
      rep.recv_timeout = 2
      loop do
        msg = rep.receive.first
        rep << "primary:#{msg}"
        puts "  primary: served #{msg}"
      rescue IO::TimeoutError
        break
      end
    end

    # Backup server: monitors heartbeats, serves after failover
    backup_ready = Queue.new
    backup_thread = Thread.new do
      rep = Cztop::Socket::REP.bind(backup_ep)
      rep.recv_timeout = 2

      # Phase 1: passive — monitor heartbeats
      sub = Cztop::Socket::SUB.connect(hb_ep, prefix: 'HB')
      sub.recv_timeout = 0.3

      backup_ready << true

      loop do
        sub.receive
      rescue IO::TimeoutError
        puts "  backup: primary heartbeat lost — taking over!"
        break
      end

      # Phase 2: active — serve requests
      loop do
        msg = rep.receive.first
        rep << "backup:#{msg}"
        puts "  backup: served #{msg}"
      rescue IO::TimeoutError
        break
      end
    end

    backup_ready.pop
    sleep 0.02

    # Client helper: try primary, fall back to backup
    send_request = lambda do |body|
      req = Cztop::Socket::REQ.connect(primary_ep)
      req.recv_timeout = 0.2
      req.linger = 0
      req << body
      reply = req.receive.first
      req.close
      reply
    rescue IO::TimeoutError
      req&.close
      req = Cztop::Socket::REQ.connect(backup_ep)
      req.recv_timeout = 1
      req.linger = 0
      req << body
      reply = req.receive.first
      req.close
      reply
    end

    # Phase 1: primary handles requests
    served_by << send_request.call('req-1')
    served_by << send_request.call('req-2')

    # Kill primary
    puts "  --- primary crashes ---"
    hb_thread.kill
    primary_thread.kill

    # Wait for backup to detect failure
    sleep 0.5

    # Phase 2: backup handles requests
    served_by << send_request.call('req-3')
    served_by << send_request.call('req-4')

    backup_thread.join(3)

    puts "  responses: #{served_by.inspect}"
    assert_equal 'primary:req-1', served_by[0]
    assert_equal 'primary:req-2', served_by[1]
    assert_equal 'backup:req-3', served_by[2]
    assert_equal 'backup:req-4', served_by[3]
  end
end
