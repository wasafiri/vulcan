class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :set_current_attributes

  include Authentication

  private

  def set_current_attributes
    Current.set_attributes(request)
  end
end
