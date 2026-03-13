# frozen_string_literal: true

require_relative '../test_helper'
require 'socket'

# --------------------------------------------------------------------------
# Shannon entropy system test for CURVE encryption
#
# Proves that CURVE-encrypted traffic on the wire is indistinguishable from
# random data by measuring Shannon entropy of the raw TCP bytes.
#
#   H(X) = -Σ p(x) log₂ p(x)    for each byte value x ∈ [0, 255]
#
# Perfect random data → H = 8.0 bits/byte.
# English text         → H ≈ 4.0–5.0
# Structured protocol  → H ≈ 3.0–6.0
# CURVE ciphertext     → H ≈ 7.8+ on the wire (ciphertext + protocol framing)
#
# The raw TCP capture includes ZMQ greeting headers and CURVE handshake
# command frames alongside the encrypted MESSAGE payloads. These structured
# bytes slightly reduce measured entropy from the theoretical 8.0 maximum.
#
# Run:   bundle exec rake test:system
# --------------------------------------------------------------------------

describe 'CURVE Shannon entropy' do
  before { skip 'CURVE not available' unless CZTop::CURVE.available? }

  BOX_WIDTH = 57

  def box(*lines)
    puts
    puts "  ┌#{'─' * BOX_WIDTH}┐"
    lines.each { |l| puts "  │  %-#{BOX_WIDTH - 3}s │" % l }
    puts "  └#{'─' * BOX_WIDTH}┘"
  end

  # Shannon entropy in bits per byte.
  #
  def shannon_entropy(data)
    total = data.bytesize.to_f
    data.bytes.tally.each_value.sum do |c|
      p = c / total
      -p * Math.log2(p)
    end
  end

  # Capture raw TCP bytes via a loopback proxy sitting between client and
  # server. Returns bytes relayed in the client → server direction
  # (CURVE handshake + encrypted MESSAGE frames).
  #
  def capture_curve_traffic(message_count: 50, payload_size: 512)
    server_pub, server_sec = CZTop::CURVE.keypair
    client_pub, client_sec = CZTop::CURVE.keypair

    auth = CZTop::CURVE::Auth.new(allowed_clients: [client_pub])

    proxy = TCPServer.new('127.0.0.1', 0)
    proxy_port = proxy.addr[1]

    server = CZTop::Socket::REP.new('tcp://127.0.0.1:*',
               curve: { secret_key: server_sec })
    server_port = server.last_tcp_port

    captured = ''.b
    proxy_thread = Thread.new do
      client_conn = proxy.accept
      server_conn = TCPSocket.new('127.0.0.1', server_port)

      loop do
        ready = IO.select([client_conn, server_conn], nil, nil, 5)
        break unless ready

        ready[0].each do |sock|
          begin
            data = sock.read_nonblock(65536)
          rescue IO::WaitReadable
            next
          rescue EOFError
            break
          end

          if sock == client_conn
            captured << data
            server_conn.write(data)
          else
            client_conn.write(data)
          end
        end
      end
    rescue
      # proxy exits when sockets close
    ensure
      client_conn&.close rescue nil
      server_conn&.close rescue nil
    end

    client = CZTop::Socket::REQ.new("tcp://127.0.0.1:#{proxy_port}",
               curve: { secret_key: client_sec, server_key: server_pub })
    client.options.sndtimeo = 5000
    client.options.rcvtimeo = 5000
    server.options.sndtimeo = 5000
    server.options.rcvtimeo = 5000

    # Payloads are deliberately low-entropy (repetitive ASCII) so we can
    # prove the wire bytes are NOT low-entropy — encryption is working.
    message_count.times do |i|
      payload = "message #{i}: #{'A' * payload_size}"
      client << payload
      msg = server.receive
      server << msg[0]
      client.receive
    end

    client.close
    server.close
    sleep 0.05
    proxy.close
    proxy_thread.join(2)
    auth.stop

    captured
  end

  # Capture plaintext TCP traffic for comparison.
  #
  def capture_plaintext_traffic(message_count: 50, payload_size: 512)
    proxy = TCPServer.new('127.0.0.1', 0)
    proxy_port = proxy.addr[1]

    server = CZTop::Socket::REP.new('tcp://127.0.0.1:*')
    server_port = server.last_tcp_port

    captured = ''.b
    proxy_thread = Thread.new do
      client_conn = proxy.accept
      server_conn = TCPSocket.new('127.0.0.1', server_port)

      loop do
        ready = IO.select([client_conn, server_conn], nil, nil, 5)
        break unless ready

        ready[0].each do |sock|
          begin
            data = sock.read_nonblock(65536)
          rescue IO::WaitReadable
            next
          rescue EOFError
            break
          end

          if sock == client_conn
            captured << data
            server_conn.write(data)
          else
            client_conn.write(data)
          end
        end
      end
    rescue
    ensure
      client_conn&.close rescue nil
      server_conn&.close rescue nil
    end

    client = CZTop::Socket::REQ.new("tcp://127.0.0.1:#{proxy_port}")
    client.options.sndtimeo = 5000
    client.options.rcvtimeo = 5000
    server.options.sndtimeo = 5000
    server.options.rcvtimeo = 5000

    message_count.times do |i|
      payload = "message #{i}: #{'A' * payload_size}"
      client << payload
      msg = server.receive
      server << msg[0]
      client.receive
    end

    client.close
    server.close
    sleep 0.05
    proxy.close
    proxy_thread.join(2)

    captured
  end


  it 'CURVE ciphertext has near-maximum Shannon entropy' do
    captured = capture_curve_traffic
    skip 'proxy captured no data' if captured.empty?

    entropy = shannon_entropy(captured)
    box("CURVE wire capture: #{captured.bytesize} bytes",
        "Shannon entropy:    #{'%.4f' % entropy} bits/byte",
        "Theoretical max:    8.0000 bits/byte",
        "Randomness:         #{'%.2f' % (entropy / 8.0 * 100)}%")

    # Wire capture includes ZMQ greetings (64 B structured headers) and
    # CURVE handshake commands (HELLO/WELCOME/INITIATE/READY with command
    # name bytes + metadata). These pull entropy slightly below 8.0.
    # Threshold of 7.8 accounts for this framing overhead.
    assert_operator entropy, :>=, 7.8,
      "CURVE ciphertext entropy #{entropy} is too low — expected ≥ 7.8 bits/byte"
  end


  it 'plaintext traffic has significantly lower entropy than CURVE' do
    plaintext_data = capture_plaintext_traffic
    curve_data     = capture_curve_traffic

    skip 'proxy captured no plaintext data' if plaintext_data.empty?
    skip 'proxy captured no CURVE data' if curve_data.empty?

    pt_entropy    = shannon_entropy(plaintext_data)
    curve_entropy = shannon_entropy(curve_data)
    delta         = curve_entropy - pt_entropy

    box("Plaintext entropy:  #{'%.4f' % pt_entropy} bits/byte  (#{plaintext_data.bytesize} bytes)",
        "CURVE entropy:      #{'%.4f' % curve_entropy} bits/byte  (#{curve_data.bytesize} bytes)",
        "Δ entropy:          #{'%.4f' % delta} bits/byte",
        "Entropy uplift:     #{'%.1f' % (delta / pt_entropy * 100)}%")

    assert_operator curve_entropy, :>, pt_entropy,
      "CURVE entropy (#{'%.4f' % curve_entropy}) should exceed plaintext (#{'%.4f' % pt_entropy})"
    assert_operator delta, :>=, 0.5,
      "Δ entropy #{delta} too small — encryption not meaningfully changing wire bytes"
  end


  it 'CURVE ciphertext covers all 256 byte values' do
    captured = capture_curve_traffic(message_count: 100, payload_size: 1024)
    skip 'proxy captured no data' if captured.empty?

    tally     = captured.bytes.tally
    coverage  = tally.size

    # How "flat" the distribution is: ratio of least-frequent to
    # most-frequent byte count. For uniform random data this → 1.0.
    min_count = tally.each_value.min
    max_count = tally.each_value.max
    flatness  = min_count.to_f / max_count

    box("Byte coverage test",
        "Sample size:        #{captured.bytesize} bytes",
        "Distinct values:    #{coverage} / 256",
        "Min bin count:      #{min_count}",
        "Max bin count:      #{max_count}",
        "Flatness ratio:     #{'%.4f' % flatness}  (1.0 = perfectly uniform)")

    assert_equal 256, coverage,
      "only #{coverage}/256 byte values present — ciphertext should cover full byte range"
  end
end
