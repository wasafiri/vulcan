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

      # Proof review statistics
      income_proofs_pending = Application.with_attached_income_proof
                                         .where(income_proof_status: 'not_reviewed')
      residency_proofs_pending = Application.with_attached_residency_proof
                                            .where(residency_proof_status: 'not_reviewed')
      data[:proofs_needing_review_count] =
        (income_proofs_pending.pluck(:id) + residency_proofs_pending.pluck(:id)).uniq.count

      data[:medical_certs_to_review_count] = Application.where(medical_certification_status: 'received').count

      # Count applications with pending training sessions
      data[:training_requests_count] = Application.joins(:training_sessions)
                                                  .where(training_sessions: { status: %i[requested scheduled confirmed] })
                                                  .distinct.count

      # Application Pipeline data for funnel chart
      data[:draft_count] = Application.where(status: 'draft').count
      data[:submitted_count] = Application.where.not(status: 'draft').count
      data[:in_review_count] = Application.where(status: %w[submitted in_review]).count
      data[:approved_count] = Application.where(status: 'approved').count

      data[:pipeline_chart_data] = {
        'Draft' => data[:draft_count],
        'Submitted' => data[:submitted_count],
        'In Review' => data[:in_review_count],
        'Approved' => data[:approved_count]
      }

      # Status Breakdown data for polar area chart
      data[:draft_count] = Application.where(status: 'draft').count
      data[:in_progress_count] = Application.where(status: %w[submitted in_review]).count
      data[:approved_count] = Application.where(status: 'approved').count
      data[:rejected_count] = Application.where(status: 'rejected').count

      data[:status_chart_data] = {
        'Draft' => data[:draft_count],
        'In Progress' => data[:in_progress_count],
        'Approved' => data[:approved_count],
        'Rejected' => data[:rejected_count]
      }

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
