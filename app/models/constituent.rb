# This is an alias to the Users::Constituent class for backward compatibility
# Future code should use Users::Constituent directly
class Constituent < User
  def self.method_missing(method, *args, &block)
    Users::Constituent.send(method, *args, &block)
  end

  def method_missing(method, *args, &block)
    Users::Constituent.instance_method(method).bind(self).call(*args, &block) if Users::Constituent.instance_methods.include?(method)
  end

  # Directly include key methods for compatibility
  DISABILITY_TYPES = Users::Constituent::DISABILITY_TYPES

  # Define core methods to avoid method_missing overhead for common calls
  def active_application?
    active_application.present?
  end

  def active_application
    applications.active.order(application_date: :desc).first
  end

  def has_disability_selected?
    hearing_disability || vision_disability || speech_disability || mobility_disability || cognition_disability
  end
end

# Explicitly load the real implementation to avoid loading order issues
require_dependency 'users/constituent'
