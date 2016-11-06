# Helper to deal with older versions of the ZMQ library (but still >= 4.0).
#
# Used to skip a few test examples on older versions of ZMQ.
#
# @note Older versions of CZMQ (like 3.0.2) are NOT supported anymore.
#   Currently this means you'll have to compile from master.
module ZMQHelper
  # This can be used to skip test examples that require a certain ZMQ version.
  # @param version [String] minimum ZMQ version
  # @return [String] if the version requirement isn't met
  # @return [nil] if the version requirement is met
  def zmq_version?(version)
    if ::CZMQ::FFI::ZMQ_VERSION < version
      "ZMQ >= #{version} required"
    end
  end

  # This can be used to skip test examples that require CZMQ draft API to be
  # available.
  #
  # @return [String] if the draft API is unavailable and thus the spec should
  #   be skipped
  # @return [false] if the draft API seems available and thus the spec should
  #   not be skipped
  #
  def no_czmq_drafts?
    # NOTE: We use some function that is currently declared DRAFT. Another one
    # might be needed in future versions.
    ::CZMQ::FFI.zproc_czmq_version
    return false
  rescue NotImplementedError, NoMethodError
    # not defined or it was just a placeholder definition from czmq-ffi-gen
    "CZMQ DRAFT API required"
  end

  # This can be used to skip test examples that require ZMQ draft API to be
  # available.
  #
  # @return [String] if the draft API is unavailable and thus the spec should
  #   be skipped
  # @return [false] if the draft API seems available and thus the spec should
  #   not be skipped
  #
  def no_zmq_drafts?
    # NOTE: We use some function that is currently declared DRAFT. Another one
    # might be needed in future versions.
    CZTop::Poller::ZMQ.poller_destroy(FFI::Pointer::NULL)
    return false
  rescue NotImplementedError
    # not defined or it was just a placeholder definition from
    # CZTop::Poller::ZMQ.attach_function
    "ZMQ DRAFT API required"
  end
end
