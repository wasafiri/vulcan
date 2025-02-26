module ConstituentPortal
  class DashboardsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_constituent!

    def show
      @applications = current_user.applications.order(created_at: :desc)

      # Set active application (most recent non-draft application)
      @active_application = @applications.where.not(status: :draft).first

      # Set draft application (most recent draft application)
      @draft_application = @applications.where(status: :draft).first
    end

    private

    def require_constituent!
      unless current_user&.constituent?
        redirect_to root_path, alert: "Access denied"
      end
    end
  end
end
