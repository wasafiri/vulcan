# frozen_string_literal: true

class BaseService
  attr_reader :errors

  def initialize
    @errors = []
  end

  protected

  def add_error(message)
    @errors << message
    false
  end

  def log_error(error, context = nil)
    message = "#{self.class.name} error: #{error.message}"
    message += " | Context: #{context}" if context
    Rails.logger.error(message)
    add_error(error.message)
  end
end
