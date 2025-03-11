class ApplicationController < ActionController::Base
  include Authentication
  protect_from_forgery with: :exception

  # Include our password field helper
  helper PasswordFieldHelper
end
