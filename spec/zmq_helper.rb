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
    # NOTE: We use some function that is currently declared DRAFT. Another one
    # might be needed in future versions.
    CZTop::Poller::ZMQ.poller_destroy(FFI::Pointer::NULL)
    true
  rescue NotImplementedError
    false
  end

  # This can be used to run certain test examples only if CZMQ draft API is
  # available.
  #
  # @return [Boolean] whether the CZMQ DRAFT API is available
  #
  def has_czmq_drafts?
    # NOTE: We use some function that is currently declared DRAFT. Another one
    # might be needed in future versions.
    ::CZMQ::FFI.zproc_czmq_version
    true
  rescue NotImplementedError
    false
  end
end
