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
end
