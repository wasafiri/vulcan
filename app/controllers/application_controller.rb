class ApplicationController < ActionController::Base
  include Authentication
  protect_from_forgery with: :exception

  # Include our helpers
  helper PasswordFieldHelper
  helper EmailStatusHelper
end
