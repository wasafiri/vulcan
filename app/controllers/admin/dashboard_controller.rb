class Admin::DashboardController < ApplicationController
  before_action :require_admin!
  include Pagy::Backend

  def index
    @current_fiscal_year = fiscal_year
    @ytd_constituents_count = Application.where("created_at >= ?", fiscal_year_start).count
    @open_applications_count = Application.where(status: :in_progress).count
    @pending_services_count = Application.where(status: :approved).count

    @pagy, @records = pagy(
      case params[:tab]
      when "need_evaluation"
        Application.approved.needs_evaluation.includes(:user)
      when "need_training"
        Application.approved.needs_training.includes(:user)
      when "equipment"
        Bid.pending_response
      else
        Application.in_progress.includes(:user)
      end,
      items: 20
     )

    @applications = @records unless params[:tab] == "equipment"
  end

  private

  def fiscal_year
    current_date = Date.current
    current_date.month >= 7 ? current_date.year : current_date.year - 1
  end

  def fiscal_year_start
    year = fiscal_year
    Date.new(year, 7, 1)
  end
end
