# frozen_string_literal: true

module Applications
  class ReportingService < BaseService
    attr_reader :fiscal_year_override

    def initialize(fiscal_year_override = nil)
      super()
      @fiscal_year_override = fiscal_year_override
    end

    # Generate dashboard reporting data
    def generate_dashboard_data
      data = {}

      # Get fiscal year data
      data[:current_fy] = current_fiscal_year
      data[:previous_fy] = data[:current_fy] - 1

      # Fiscal year date ranges
      data[:current_fy_start] = Date.new(data[:current_fy], 7, 1)
      data[:current_fy_end] = Date.new(data[:current_fy] + 1, 6, 30)
      data[:previous_fy_start] = Date.new(data[:previous_fy], 7, 1)
      data[:previous_fy_end] = Date.new(data[:current_fy], 6, 30)

      # Applications data
      data[:current_fy_applications] =
        Application.where(created_at: data[:current_fy_start]..data[:current_fy_end]).count
      data[:previous_fy_applications] =
        Application.where(created_at: data[:previous_fy_start]..data[:previous_fy_end]).count

      # Draft applications (started but not submitted)
      data[:current_fy_draft_applications] =
        Application.where(status: :draft, created_at: data[:current_fy_start]..data[:current_fy_end]).count
      data[:previous_fy_draft_applications] =
        Application.where(status: :draft, created_at: data[:previous_fy_start]..data[:previous_fy_end]).count

      # Vouchers data
      data[:current_fy_vouchers] = Voucher.where(created_at: data[:current_fy_start]..data[:current_fy_end]).count
      data[:previous_fy_vouchers] = Voucher.where(created_at: data[:previous_fy_start]..data[:previous_fy_end]).count

      # Unredeemed vouchers
      data[:current_fy_unredeemed_vouchers] =
        Voucher.where(created_at: data[:current_fy_start]..data[:current_fy_end], status: :active).count
      data[:previous_fy_unredeemed_vouchers] =
        Voucher.where(created_at: data[:previous_fy_start]..data[:previous_fy_end], status: :active).count

      # Voucher values
      data[:current_fy_voucher_value] =
        Voucher.where(created_at: data[:current_fy_start]..data[:current_fy_end]).sum(:initial_value)
      data[:previous_fy_voucher_value] =
        Voucher.where(created_at: data[:previous_fy_start]..data[:previous_fy_end]).sum(:initial_value)

      # Training sessions
      data[:current_fy_trainings] =
        TrainingSession.where(created_at: data[:current_fy_start]..data[:current_fy_end]).count
      data[:previous_fy_trainings] =
        TrainingSession.where(created_at: data[:previous_fy_start]..data[:previous_fy_end]).count

      # Evaluation sessions
      data[:current_fy_evaluations] = Evaluation.where(created_at: data[:current_fy_start]..data[:current_fy_end]).count
      data[:previous_fy_evaluations] =
        Evaluation.where(created_at: data[:previous_fy_start]..data[:previous_fy_end]).count

      # Vendor activity
      data[:active_vendors] = Vendor.joins(:voucher_transactions).distinct.count
      data[:recent_active_vendors] = Vendor.joins(:voucher_transactions)
                                           .where('voucher_transactions.created_at >= ?', 1.month.ago)
                                           .distinct.count

      # MFR Data (previous full fiscal year)
      data[:mfr_applications_approved] =
        Application.where(created_at: data[:previous_fy_start]..data[:previous_fy_end], status: :approved).count
      data[:mfr_vouchers_issued] = Voucher.where(created_at: data[:previous_fy_start]..data[:previous_fy_end]).count

      # Chart data for applications
      data[:applications_chart_data] = {
        current: { 'Applications' => data[:current_fy_applications],
                   'Draft Applications' => data[:current_fy_draft_applications] },
        previous: { 'Applications' => data[:previous_fy_applications],
                    'Draft Applications' => data[:previous_fy_draft_applications] }
      }

      # Chart data for vouchers
      data[:vouchers_chart_data] = {
        current: { 'Vouchers Issued' => data[:current_fy_vouchers],
                   'Unredeemed Vouchers' => data[:current_fy_unredeemed_vouchers] },
        previous: { 'Vouchers Issued' => data[:previous_fy_vouchers],
                    'Unredeemed Vouchers' => data[:previous_fy_unredeemed_vouchers] }
      }

      # Chart data for services
      data[:services_chart_data] = {
        current: { 'Training Sessions' => data[:current_fy_trainings],
                   'Evaluation Sessions' => data[:current_fy_evaluations] },
        previous: { 'Training Sessions' => data[:previous_fy_trainings],
                    'Evaluation Sessions' => data[:previous_fy_evaluations] }
      }

      # Chart data for MFR
      data[:mfr_chart_data] = {
        current: { 'Applications Approved' => data[:mfr_applications_approved],
                   'Vouchers Issued' => data[:mfr_vouchers_issued] },
        previous: { 'Applications Approved' => 0, 'Vouchers Issued' => 0 } # Empty for comparison
      }

      data
    rescue StandardError => e
      Rails.logger.error "Error generating dashboard data: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      add_error("Error generating dashboard data: #{e.message}")
      {}
    end

    # Generate index data for the applications index page
    def generate_index_data
      data = {}

      data[:current_fiscal_year] = current_fiscal_year
      data[:total_users_count] = User.count
      data[:ytd_constituents_count] = Application.where('created_at >= ?', fiscal_year_start).count
      data[:open_applications_count] = Application.active.count
      data[:pending_services_count] = Application.where(status: :approved).count

      # Load recent notifications
      notifications = Notification.select('id, recipient_id, actor_id, notifiable_id, notifiable_type, action, read_at, created_at, message_id, delivery_status, metadata')
                                  .order(created_at: :desc)
                                  .limit(5)

      data[:recent_notifications] = notifications.map { |n| NotificationDecorator.new(n) }

      # Fetch all status counts in one query
      status_counts = Application.group(:status).count
      status_counts.default = 0 # Ensure keys exist even if count is 0

      # Proof review statistics - Optimized query without with_attached_*
      data[:proofs_needing_review_count] = Application
                                           .where(income_proof_status: :not_reviewed)
                                           .or(Application.where(residency_proof_status: :not_reviewed))
                                           .distinct
                                           .count

      data[:medical_certs_to_review_count] = Application
                                             .where.not(status: %i[rejected archived])
                                             .where(medical_certification_status: :received)
                                             .count

      # Count applications with pending training sessions
      data[:training_requests_count] = Application
                                       .joins(:training_sessions)
                                       .where(training_sessions: { status: %i[requested scheduled confirmed] })
                                       .distinct
                                       .count

      # Use grouped status counts for charts
      draft_count = status_counts[Application.statuses[:draft]]
      submitted_count = status_counts[Application.statuses[:submitted]]
      in_review_count = status_counts[Application.statuses[:in_review]]
      approved_count = status_counts[Application.statuses[:approved]]
      rejected_count = status_counts[Application.statuses[:rejected]]

      # Application Pipeline data for funnel chart
      total_submitted_or_later = submitted_count + in_review_count + approved_count + rejected_count # Approximation
      total_in_review_or_later = in_review_count + approved_count + rejected_count # Approximation

      data[:pipeline_chart_data] = {
        'Draft' => draft_count,
        'Submitted' => total_submitted_or_later, # Represents apps that passed draft
        'In Review' => total_in_review_or_later, # Represents apps that passed submission
        'Approved' => approved_count
      }

      # Status Breakdown data for polar area chart
      in_progress_combined_count = submitted_count + in_review_count # Combine for 'In Progress'

      data[:status_chart_data] = {
        'Draft' => draft_count,
        'In Progress' => in_progress_combined_count,
        'Approved' => approved_count,
        'Rejected' => rejected_count
      }

      # Add individual counts if needed elsewhere (though charts use combined values)
      data[:draft_count] = draft_count
      data[:submitted_count] = submitted_count
      data[:in_review_count] = in_review_count
      data[:approved_count] = approved_count
      data[:rejected_count] = rejected_count
      data[:in_progress_count] = in_progress_combined_count # Keep for consistency if used directly

      data
    rescue StandardError => e
      Rails.logger.error "Error generating index data: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      add_error("Error generating index data: #{e.message}")
      {}
    end

    private

    def current_fiscal_year
      return fiscal_year_override if fiscal_year_override.present?

      current_date = Date.current
      current_date.month >= 7 ? current_date.year : current_date.year - 1
    end

    def fiscal_year_start
      year = current_fiscal_year
      Date.new(year, 7, 1)
    end
  end
end
