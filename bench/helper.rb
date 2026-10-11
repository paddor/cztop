# frozen_string_literal: true

require 'cztop'
require 'benchmark/ips'
require 'tmpdir'

module CZTopBench
  MSG_SIZES = [64, 256, 1024, 4096].freeze
  TRANSPORTS = %w[inproc ipc tcp].freeze

  def self.print_environment(mode)
    puts "CZMQ #{CZMQ::FFI::CZMQ_VERSION} | ZMQ #{CZMQ::FFI::ZMQ_VERSION} | #{RUBY_DESCRIPTION} (#{mode})"
    puts
  end

  def self.with_sockets(transport, receiver_type, sender_type)
    Dir.mktmpdir('cztop-bench-') do |dir|
      endpoint = case transport
                 when 'inproc' then "inproc://#{dir}"
                 when 'ipc' then "ipc://#{dir}/socket"
                 when 'tcp' then 'tcp://127.0.0.1:*'
                 else raise ArgumentError, "unknown transport: #{transport}"
                 end
      receiver = receiver_type.bind(endpoint)
      sender = sender_type.connect(receiver.last_endpoint)
      yield receiver, sender
    ensure
      sender&.close
      receiver&.close
    end
  end
end
