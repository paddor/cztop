# Helper to deal with older versions of CZMQ.
#
# Used to skip a few test examples on the current stable release 3.0.2 of
# CZMQ, because it lacks a few functions/bug fixes.
module CZMQHelper
  # This can be used to skip test examples that require a certain CZMQ
  # function to be available.
  #
  # @param function_name [Symbol] function to be checked
  # @return [String] if the function is unavailable
  # @return [nil] if the function is available
  def czmq_function?(function_name)
    unless ::CZMQ::FFI.respond_to?(function_name)
      "CZMQ function #{function_name}() is unavailable"
    end
  end

  # This can be used to skip test examples that require a certain CZMQ
  # feature to be available. Since sometimes the feature itself can't be
  # checked, a function (younger than the feature) can be used instead.
  #
  # @param feature_name [String] name or short description of feature
  # @param function_name [Symbol] function that is about the same age or
  #   younger than the feature
  # @return [String] if the feature is unavailable
  # @return [nil] if the function is available
  def czmq_feature?(feature_name, function_name)
    czmq_function?(function_name) and
      "CZMQ feature #{feature_name.inspect} is unavailable"
  end
end
