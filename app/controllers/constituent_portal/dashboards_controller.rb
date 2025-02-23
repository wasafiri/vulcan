module ConstituentPortal
  class DashboardsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_constituent!

    def show
      @applications = current_user.applications.order(created_at: :desc)
    end

    private

    def require_constituent!
      unless current_user&.constituent?
        redirect_to root_path, alert: "Access denied"
      end
    end
  end
end
