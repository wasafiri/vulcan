# frozen_string_literal: true

module Admin
  class ReportsController < Admin::BaseController
    def index
      # Reuse the existing data loading method
      load_quick_reports_data
    end

    def show; end

    def equipment_distribution; end

    def evaluation_metrics; end

    def vendor_performance; end

    private

    # Copy the load_quick_reports_data method from ApplicationsController, using safe_assign
    def load_quick_reports_data
      # Use the safe_assign method to prevent instance variable name errors
      current_fy = fiscal_year
      previous_fy = current_fy - 1

      # Current and previous fiscal year date ranges
      current_fy_start = Date.new(current_fy, 7, 1)
      current_fy_end = Date.new(current_fy + 1, 6, 30)
      previous_fy_start = Date.new(previous_fy, 7, 1)
      previous_fy_end = Date.new(current_fy, 6, 30)

      # Safely assign basic fiscal year variables
      safe_assign(:current_fy, current_fy)
      safe_assign(:previous_fy, previous_fy)
      safe_assign(:current_fy_start, current_fy_start)
      safe_assign(:current_fy_end, current_fy_end)
      safe_assign(:previous_fy_start, previous_fy_start)
      safe_assign(:previous_fy_end, previous_fy_end)

      # Applications data
      safe_assign(:current_fy_applications, Application.where(created_at: current_fy_start..current_fy_end).count)
      safe_assign(:previous_fy_applications, Application.where(created_at: previous_fy_start..previous_fy_end).count)

      # Draft applications (started but not submitted)
      safe_assign(:current_fy_draft_applications, Application.where(status: :draft,
                                                                    created_at: current_fy_start..current_fy_end).count)
      safe_assign(:previous_fy_draft_applications, Application.where(status: :draft,
                                                                     created_at: previous_fy_start..previous_fy_end).count)

      # Vouchers data
      safe_assign(:current_fy_vouchers, Voucher.where(created_at: current_fy_start..current_fy_end).count)
      safe_assign(:previous_fy_vouchers, Voucher.where(created_at: previous_fy_start..previous_fy_end).count)

      # Unredeemed vouchers
      safe_assign(:current_fy_unredeemed_vouchers, Voucher.where(created_at: current_fy_start..current_fy_end,
                                                                 status: :active).count)
      safe_assign(:previous_fy_unredeemed_vouchers, Voucher.where(created_at: previous_fy_start..previous_fy_end,
                                                                  status: :active).count)

      # Voucher values
      safe_assign(:current_fy_voucher_value, Voucher.where(created_at: current_fy_start..current_fy_end).sum(:initial_value))
      safe_assign(:previous_fy_voucher_value, Voucher.where(created_at: previous_fy_start..previous_fy_end).sum(:initial_value))

      # Training sessions
      safe_assign(:current_fy_trainings, TrainingSession.where(created_at: current_fy_start..current_fy_end).count)
      safe_assign(:previous_fy_trainings, TrainingSession.where(created_at: previous_fy_start..previous_fy_end).count)

      # Evaluation sessions
      safe_assign(:current_fy_evaluations, Evaluation.where(created_at: current_fy_start..current_fy_end).count)
      safe_assign(:previous_fy_evaluations, Evaluation.where(created_at: previous_fy_start..previous_fy_end).count)

      # Vendor activity
      safe_assign(:active_vendors, Vendor.joins(:voucher_transactions).distinct.count)
      safe_assign(:recent_active_vendors, Vendor.joins(:voucher_transactions)
                                             .where('voucher_transactions.created_at >= ?', 1.month.ago)
                                             .distinct.count)

      # MFR Data (previous full fiscal year)
      safe_assign(:mfr_applications_approved, Application.where(created_at: previous_fy_start..previous_fy_end,
                                                                status: :approved).count)
      safe_assign(:mfr_vouchers_issued, Voucher.where(created_at: previous_fy_start..previous_fy_end).count)

      # Get variables for chart data
      current_fy_applications = instance_variable_get('@current_fy_applications')
      previous_fy_applications = instance_variable_get('@previous_fy_applications')
      current_fy_draft_applications = instance_variable_get('@current_fy_draft_applications')
      previous_fy_draft_applications = instance_variable_get('@previous_fy_draft_applications')
      current_fy_vouchers = instance_variable_get('@current_fy_vouchers')
      previous_fy_vouchers = instance_variable_get('@previous_fy_vouchers')
      current_fy_unredeemed_vouchers = instance_variable_get('@current_fy_unredeemed_vouchers')
      previous_fy_unredeemed_vouchers = instance_variable_get('@previous_fy_unredeemed_vouchers')
      current_fy_trainings = instance_variable_get('@current_fy_trainings')
      previous_fy_trainings = instance_variable_get('@previous_fy_trainings')
      current_fy_evaluations = instance_variable_get('@current_fy_evaluations')
      previous_fy_evaluations = instance_variable_get('@previous_fy_evaluations')
      mfr_applications_approved = instance_variable_get('@mfr_applications_approved')
      mfr_vouchers_issued = instance_variable_get('@mfr_vouchers_issued')

      # Chart data for applications
      safe_assign(:applications_chart_data, {
                    current: { 'Applications' => current_fy_applications, 'Draft Applications' => current_fy_draft_applications },
                    previous: { 'Applications' => previous_fy_applications,
                                'Draft Applications' => previous_fy_draft_applications }
                  })

      # Chart data for vouchers
      safe_assign(:vouchers_chart_data, {
                    current: { 'Vouchers Issued' => current_fy_vouchers,
                               'Unredeemed Vouchers' => current_fy_unredeemed_vouchers },
                    previous: { 'Vouchers Issued' => previous_fy_vouchers,
                                'Unredeemed Vouchers' => previous_fy_unredeemed_vouchers }
                  })

      # Chart data for services
      safe_assign(:services_chart_data, {
                    current: { 'Training Sessions' => current_fy_trainings, 'Evaluation Sessions' => current_fy_evaluations },
                    previous: { 'Training Sessions' => previous_fy_trainings, 'Evaluation Sessions' => previous_fy_evaluations }
                  })

      # Chart data for MFR
      safe_assign(:mfr_chart_data, {
                    current: { 'Applications Approved' => mfr_applications_approved, 'Vouchers Issued' => mfr_vouchers_issued },
                    previous: { 'Applications Approved' => 0, 'Vouchers Issued' => 0 } # Empty for comparison
                  })
    end

    def fiscal_year
      current_date = Date.current
      current_date.month >= 7 ? current_date.year : current_date.year - 1
    end
  end
end
