class Admin::ReportsController < Admin::BaseController
  def index
    # Reuse the existing data loading method
    load_quick_reports_data
  end

  def show
  end

  def equipment_distribution
  end

  def evaluation_metrics
  end

  def vendor_performance
  end

  private

  # Copy the load_quick_reports_data method from ApplicationsController
  def load_quick_reports_data
    @current_fy = fiscal_year
    @previous_fy = @current_fy - 1

    # Current and previous fiscal year date ranges
    @current_fy_start = Date.new(@current_fy, 7, 1)
    @current_fy_end = Date.new(@current_fy + 1, 6, 30)
    @previous_fy_start = Date.new(@previous_fy, 7, 1)
    @previous_fy_end = Date.new(@current_fy, 6, 30)

    # Applications data
    @current_fy_applications = Application.where(created_at: @current_fy_start..@current_fy_end).count
    @previous_fy_applications = Application.where(created_at: @previous_fy_start..@previous_fy_end).count

    # Draft applications (started but not submitted)
    @current_fy_draft_applications = Application.where(status: :draft, created_at: @current_fy_start..@current_fy_end).count
    @previous_fy_draft_applications = Application.where(status: :draft, created_at: @previous_fy_start..@previous_fy_end).count

    # Vouchers data
    @current_fy_vouchers = Voucher.where(created_at: @current_fy_start..@current_fy_end).count
    @previous_fy_vouchers = Voucher.where(created_at: @previous_fy_start..@previous_fy_end).count

    # Unredeemed vouchers
    @current_fy_unredeemed_vouchers = Voucher.where(created_at: @current_fy_start..@current_fy_end, status: :issued).count
    @previous_fy_unredeemed_vouchers = Voucher.where(created_at: @previous_fy_start..@previous_fy_end, status: :issued).count

    # Voucher values
    @current_fy_voucher_value = Voucher.where(created_at: @current_fy_start..@current_fy_end).sum(:initial_value)
    @previous_fy_voucher_value = Voucher.where(created_at: @previous_fy_start..@previous_fy_end).sum(:initial_value)

    # Training sessions
    @current_fy_trainings = TrainingSession.where(created_at: @current_fy_start..@current_fy_end).count
    @previous_fy_trainings = TrainingSession.where(created_at: @previous_fy_start..@previous_fy_end).count

    # Evaluation sessions
    @current_fy_evaluations = Evaluation.where(created_at: @current_fy_start..@current_fy_end).count
    @previous_fy_evaluations = Evaluation.where(created_at: @previous_fy_start..@previous_fy_end).count

    # Vendor activity
    @active_vendors = Vendor.joins(:voucher_transactions).distinct.count
    @recent_active_vendors = Vendor.joins(:voucher_transactions)
                                  .where("voucher_transactions.created_at >= ?", 1.month.ago)
                                  .distinct.count

    # MFR Data (previous full fiscal year)
    @mfr_applications_approved = Application.where(created_at: @previous_fy_start..@previous_fy_end, status: :approved).count
    @mfr_vouchers_issued = Voucher.where(created_at: @previous_fy_start..@previous_fy_end).count

    # Chart data for applications
    @applications_chart_data = {
      current: { "Applications" => @current_fy_applications, "Draft Applications" => @current_fy_draft_applications },
      previous: { "Applications" => @previous_fy_applications, "Draft Applications" => @previous_fy_draft_applications }
    }

    # Chart data for vouchers
    @vouchers_chart_data = {
      current: { "Vouchers Issued" => @current_fy_vouchers, "Unredeemed Vouchers" => @current_fy_unredeemed_vouchers },
      previous: { "Vouchers Issued" => @previous_fy_vouchers, "Unredeemed Vouchers" => @previous_fy_unredeemed_vouchers }
    }

    # Chart data for services
    @services_chart_data = {
      current: { "Training Sessions" => @current_fy_trainings, "Evaluation Sessions" => @current_fy_evaluations },
      previous: { "Training Sessions" => @previous_fy_trainings, "Evaluation Sessions" => @previous_fy_evaluations }
    }

    # Chart data for MFR
    @mfr_chart_data = {
      current: { "Applications Approved" => @mfr_applications_approved, "Vouchers Issued" => @mfr_vouchers_issued },
      previous: { "Applications Approved" => 0, "Vouchers Issued" => 0 } # Empty for comparison
    }
  end

  def fiscal_year
    current_date = Date.current
    current_date.month >= 7 ? current_date.year : current_date.year - 1
  end
end
