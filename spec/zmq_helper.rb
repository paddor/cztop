# frozen_string_literal: true

# Helper to deal with certain version or build differences of the ZMQ and CZMQ
# libraries.
#
module ZMQHelper

  # This can be used to run certain test examples only if the required minimal
  # ZMQ version is available.
  #
  # @param version [String] minimal ZMQ version
  # @return [Boolean] whether minimal ZMQ version is available
  #
  def has_zmq_version?(version)
    ::CZMQ::FFI::ZMQ_VERSION >= version
  end


  # This can be used to run certain test examples only if the required minimal
  # CZMQ version is available.
  #
  # @param version [String] minimal CZMQ version
  # @return [Boolean] whether minimal CZMQ version is available
  #
  def has_czmq_version?(version)
    ::CZMQ::FFI::CZMQ_VERSION >= version
  end


  # This can be used to run certain test examples only if ZMQ draft API is
  # available.
  #
  # @return [Boolean] whether the ZMQ DRAFT API is available
  #
  def has_zmq_drafts?
    CZMQ::FFI::LibZMQ.has_draft?
  end


  # This can be used to run certain test examples only if CZMQ draft API is
  # available.
  #
  # @return [Boolean] whether the CZMQ DRAFT API is available
  #
  def has_czmq_drafts?
    ::CZMQ::FFI.has_draft?
  end

end
