class Vendor::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :require_vendor!

  private

  def require_vendor!
    unless current_user&.vendor?
      redirect_to root_path, alert: "Access denied. Vendor-only area."
    end
  end
end
