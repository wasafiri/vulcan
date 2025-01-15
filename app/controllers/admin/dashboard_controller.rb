class Admin::DashboardController < ApplicationController
  before_action :require_admin!
  include Pagy::Backend

  def index
    @current_fiscal_year = fiscal_year
    @total_users_count = User.count
    @ytd_constituents_count = Application.where("created_at >= ?", fiscal_year_start).count
    @open_applications_count = Application.active.count
    @pending_services_count = Application.where(status: :approved).count

    # Get base scope with includes
    scope = Application.includes(:user, :income_proof_attachment, :residency_proof_attachment)
      .where.not(status: [ :rejected, :archived ])

    # Apply filters
    scope = case params[:filter]
    when "in_progress"
      scope.where(status: :in_progress)
    when "approved"
      scope.where(status: :approved)
    when "proofs_needing_review"
      scope.where(income_proof_status: 0)
           .or(scope.where(residency_proof_status: 0))
    when "awaiting_medical_response"
      scope.where(status: :awaiting_documents)
    else
      scope
    end

    @pagy, @applications = pagy(scope, items: 20)
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
