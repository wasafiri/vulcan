# frozen_string_literal: true

# Base class for all service objects in the application
# Provides common functionality and structure
class BaseService
  # Default result object returned by services
  Result = Struct.new(:success, :message, :data, keyword_init: true) do
    def success?
      success == true
    end

    def failure?
      !success?
    end
  end

  def initialize(*_args)
    # Base initialization - may be overridden by subclasses
  end

  # Returns a success result with optional message and data
  def success(message = nil, data = nil)
    Result.new(success: true, message: message, data: data)
  end

  # Returns a failure result with optional message and data
  def failure(message = nil, data = nil)
    Result.new(success: false, message: message, data: data)
  end
end
