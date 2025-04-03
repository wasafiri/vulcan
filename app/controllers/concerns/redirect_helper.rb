# frozen_string_literal: true

# Provides standardized redirect methods with flash messages
# Can be included in any controller that needs consistent redirect behavior
module RedirectHelper
  extend ActiveSupport::Concern

  # Redirects with a notice message
  # @param path [String, Object] The path or object to redirect to
  # @param message [String] The notice message
  def redirect_with_notice(path, message)
    redirect_to path, notice: message
  end

  # Redirects with an alert message
  # @param path [String, Object] The path or object to redirect to
  # @param message [String] The alert message
  def redirect_with_alert(path, message)
    redirect_to path, alert: message
  end
end
