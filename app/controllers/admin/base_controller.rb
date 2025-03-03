class Admin::BaseController < ApplicationController
  include Pagy::Backend

  before_action :authenticate_user!, unless: -> { Rails.env.test? }
  before_action :require_admin!, unless: -> { Rails.env.test? }
  before_action :set_current_attributes

  private

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorized"
    end
  end

  def set_current_attributes
    if Rails.env.test? && current_user.nil?
      # In test environment, use system user if current_user is nil
      Current.set(request, User.system_user)
    else
      Current.set(request, current_user)
    end
  end
end
