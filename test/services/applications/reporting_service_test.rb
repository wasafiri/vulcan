# frozen_string_literal: true

require 'test_helper'

module Applications
  class ReportingServiceTest < ActiveSupport::TestCase
    setup do
      @admin = create(:admin)
      @user = create(:user) # Basic user
    end

    test 'generates dashboard data with correct fiscal year information' do
      # Set up applications with known dates
      current_fy_year = Date.current.month >= 7 ? Date.current.year : Date.current.year - 1
      current_fy_start = Date.new(current_fy_year, 7, 1)
      previous_fy_start = Date.new(current_fy_year - 1, 7, 1)

      # Create applications with specific statuses and dates for reporting tests
      # 1 Draft application
      draft_app = create(:application, created_at: current_fy_start + 1.month, status: :draft)

      # 2 In-progress applications (submitted by constituent)
      submitted_app1 = create(:application, created_at: current_fy_start + 2.months, status: :in_progress)
      submitted_app2 = create(:application, created_at: current_fy_start + 3.months, status: :in_progress)

      # 0 In Review applications (not created)

      # 3 Approved applications (2 current FY, 1 previous FY)
      approved_app1 = create(:application, created_at: current_fy_start + 4.months, status: :approved)
      approved_app2 = create(:application, created_at: current_fy_start + 5.months, status: :approved) # Added another approved app in current FY
      approved_app3 = create(:application, created_at: previous_fy_start + 1.month, status: :approved) # Previous FY

      # Set up mocks for ActiveStorage attachments to prevent byte_size() errors
      setup_attachment_mocks_for_audit_logs

      with_mocked_attachments do
        service = ReportingService.new
        data = service.generate_dashboard_data

        # Verify fiscal year data
        assert_equal current_fy_year, data[:current_fy]
        assert_equal current_fy_year - 1, data[:previous_fy]

        # Verify date ranges
        assert_equal current_fy_start, data[:current_fy_start]
        assert_equal Date.new(current_fy_year + 1, 6, 30), data[:current_fy_end]
        assert_equal previous_fy_start, data[:previous_fy_start]
        assert_equal Date.new(current_fy_year, 6, 30), data[:previous_fy_end]
      end
    end

    test 'counts applications correctly' do
      # Set up applications with known dates
      current_fy_year = Date.current.month >= 7 ? Date.current.year : Date.current.year - 1
      current_fy_start = Date.new(current_fy_year, 7, 1)
      previous_fy_start = Date.new(current_fy_year - 1, 7, 1)

      # Create applications with specific statuses and dates for reporting tests
      # 1 Draft application
      draft_app = create(:application, created_at: current_fy_start + 1.month, status: :draft)

      # 2 In-progress applications (submitted by constituent)
      submitted_app1 = create(:application, created_at: current_fy_start + 2.months, status: :in_progress)
      submitted_app2 = create(:application, created_at: current_fy_start + 3.months, status: :in_progress)

      # 0 In Review applications (not created)

      # 3 Approved applications (2 current FY, 1 previous FY)
      approved_app1 = create(:application, created_at: current_fy_start + 4.months, status: :approved)
      approved_app2 = create(:application, created_at: current_fy_start + 5.months, status: :approved) # Added another approved app in current FY
      approved_app3 = create(:application, created_at: previous_fy_start + 1.month, status: :approved) # Previous FY

      # Set up mocks for ActiveStorage attachments to prevent byte_size() errors
      setup_attachment_mocks_for_audit_logs

      with_mocked_attachments do
        service = ReportingService.new
        data = service.generate_dashboard_data

        # Verify application counts
        # Total applications in current FY: 1 draft + 2 submitted + 2 approved = 5
        # Total applications in previous FY: 1 approved = 1
        assert_equal 5, data[:current_fy_applications]
        assert_equal 1, data[:previous_fy_applications]

        # Verify draft applications count
        assert_equal 1, data[:current_fy_draft_applications]
        assert_equal 0, data[:previous_fy_draft_applications]
      end
    end

    test 'counts vouchers correctly' do
      # Set up applications with known dates
      current_fy_year = Date.current.month >= 7 ? Date.current.year : Date.current.year - 1
      current_fy_start = Date.new(current_fy_year, 7, 1)
      previous_fy_start = Date.new(current_fy_year - 1, 7, 1)

      # Create applications with specific statuses and dates for reporting tests
      # 1 Draft application
      draft_app = create(:application, created_at: current_fy_start + 1.month, status: :draft)

      # 2 In-progress applications (submitted by constituent)
      submitted_app1 = create(:application, created_at: current_fy_start + 2.months, status: :in_progress)
      submitted_app2 = create(:application, created_at: current_fy_start + 3.months, status: :in_progress)

      # 0 In Review applications (not created)

      # 3 Approved applications (2 current FY, 1 previous FY)
      approved_app1 = create(:application, created_at: current_fy_start + 4.months, status: :approved)
      approved_app2 = create(:application, created_at: current_fy_start + 5.months, status: :approved) # Added another approved app in current FY
      approved_app3 = create(:application, created_at: previous_fy_start + 1.month, status: :approved) # Previous FY

      # Set up mocks for ActiveStorage attachments to prevent byte_size() errors
      setup_attachment_mocks_for_audit_logs

      # Create some vouchers using factories
      _current_voucher = create(:voucher, :active,
                                initial_value: 100,
                                remaining_value: 100,
                                application: approved_app1, # Associate with an approved app
                                created_at: current_fy_start + 1.month) # Match app date

      _previous_voucher = create(:voucher, :redeemed,
                                 initial_value: 200,
                                 remaining_value: 0,
                                 application: approved_app2, # Associate with a previous FY approved app
                                 created_at: previous_fy_start + 1.month) # Match app date

      with_mocked_attachments do
        service = ReportingService.new
        data = service.generate_dashboard_data

        # Verify voucher counts
        assert_equal 1, data[:current_fy_vouchers]
        assert_equal 1, data[:previous_fy_vouchers]

        # Verify active vouchers count
        assert_equal 1, data[:current_fy_unredeemed_vouchers]
        assert_equal 0, data[:previous_fy_unredeemed_vouchers]

        # Verify voucher values
        assert_equal 100, data[:current_fy_voucher_value]
        assert_equal 200, data[:previous_fy_voucher_value]
      end
    end

    test 'includes chart data in dashboard' do
      # Set up applications with known dates
      current_fy_year = Date.current.month >= 7 ? Date.current.year : Date.current.year - 1
      current_fy_start = Date.new(current_fy_year, 7, 1)
      previous_fy_start = Date.new(current_fy_year - 1, 7, 1)

      # Create applications with specific statuses and dates for reporting tests
      # 1 Draft application
      draft_app = create(:application, created_at: current_fy_start + 1.month, status: :draft)

      # 2 In-progress applications (submitted by constituent)
      submitted_app1 = create(:application, created_at: current_fy_start + 2.months, status: :in_progress)
      submitted_app2 = create(:application, created_at: current_fy_start + 3.months, status: :in_progress)

      # 0 In Review applications (not created)

      # 3 Approved applications (2 current FY, 1 previous FY)
      approved_app1 = create(:application, created_at: current_fy_start + 4.months, status: :approved)
      approved_app2 = create(:application, created_at: current_fy_start + 5.months, status: :approved) # Added another approved app in current FY
      approved_app3 = create(:application, created_at: previous_fy_start + 1.month, status: :approved) # Previous FY

      # Set up mocks for ActiveStorage attachments to prevent byte_size() errors
      setup_attachment_mocks_for_audit_logs

      with_mocked_attachments do
        service = ReportingService.new
        data = service.generate_dashboard_data

        # Verify chart data exists
        assert data[:applications_chart_data].present?
        assert data[:vouchers_chart_data].present?
        assert data[:services_chart_data].present?
        assert data[:mfr_chart_data].present?

        # Verify specific chart data (based on new setup)
        # Current FY: 1 draft + 2 submitted + 2 approved = 5
        # Previous FY: 1 approved = 1
        assert_equal 5, data[:applications_chart_data][:current]['Applications']
        assert_equal 1, data[:applications_chart_data][:previous]['Applications']
      end
    end

    test 'allows fiscal year override' do
      # Set up applications with known dates
      current_fy_year = Date.current.month >= 7 ? Date.current.year : Date.current.year - 1
      current_fy_start = Date.new(current_fy_year, 7, 1)
      previous_fy_start = Date.new(current_fy_year - 1, 7, 1)

      # Create applications with specific statuses and dates for reporting tests
      # 1 Draft application
      draft_app = create(:application, created_at: current_fy_start + 1.month, status: :draft)

      # 2 In-progress applications (submitted by constituent)
      submitted_app1 = create(:application, created_at: current_fy_start + 2.months, status: :in_progress)
      submitted_app2 = create(:application, created_at: current_fy_start + 3.months, status: :in_progress)

      # 0 In Review applications (not created)

      # 3 Approved applications (2 current FY, 1 previous FY)
      approved_app1 = create(:application, created_at: current_fy_start + 4.months, status: :approved)
      approved_app2 = create(:application, created_at: current_fy_start + 5.months, status: :approved) # Added another approved app in current FY
      approved_app3 = create(:application, created_at: previous_fy_start + 1.month, status: :approved) # Previous FY

      # Set up mocks for ActiveStorage attachments to prevent byte_size() errors
      setup_attachment_mocks_for_audit_logs

      with_mocked_attachments do
        # Create a service with a specific fiscal year
        service = ReportingService.new(2023)
        data = service.generate_dashboard_data

        # Verify fiscal year data
        assert_equal 2023, data[:current_fy]
        assert_equal 2022, data[:previous_fy]

        # Verify date ranges
        assert_equal Date.new(2023, 7, 1), data[:current_fy_start]
        assert_equal Date.new(2024, 6, 30), data[:current_fy_end]
        assert_equal Date.new(2022, 7, 1), data[:previous_fy_start]
        assert_equal Date.new(2023, 6, 30), data[:previous_fy_end]
      end
    end

    test 'generates index data with required statistics' do
      # Set up applications with known dates
      current_fy_year = Date.current.month >= 7 ? Date.current.year : Date.current.year - 1
      current_fy_start = Date.new(current_fy_year, 7, 1)
      previous_fy_start = Date.new(current_fy_year - 1, 7, 1)

      # Create applications with specific statuses and dates for reporting tests
      # 1 Draft application
      draft_app = create(:application, created_at: current_fy_start + 1.month, status: :draft)

      # 2 In-progress applications (submitted by constituent)
      submitted_app1 = create(:application, created_at: current_fy_start + 2.months, status: :in_progress)
      submitted_app2 = create(:application, created_at: current_fy_start + 3.months, status: :in_progress)

      # 0 In Review applications (not created)

      # 3 Approved applications (2 current FY, 1 previous FY)
      approved_app1 = create(:application, created_at: current_fy_start + 4.months, status: :approved)
      approved_app2 = create(:application, created_at: current_fy_start + 5.months, status: :approved) # Added another approved app in current FY
      approved_app3 = create(:application, created_at: previous_fy_start + 1.month, status: :approved) # Previous FY

      # Set up mocks for ActiveStorage attachments to prevent byte_size() errors
      setup_attachment_mocks_for_audit_logs

      with_mocked_attachments do
        # Verify the actual statuses stored in the database
        puts "Draft App Status: #{draft_app.reload.status}, Status Value: #{draft_app.reload.status_before_type_cast}"
        puts "Submitted App1 Status: #{submitted_app1.reload.status}, Status Value: #{submitted_app1.reload.status_before_type_cast}"

        # Check status counts directly
        status_counts = Application.group(:status).count
        puts "Raw Status Counts: #{status_counts.inspect}"
        puts "Draft Enum Value: #{Application.statuses[:draft]}"

        # Try the service
        service = ReportingService.new
        data = service.generate_index_data

        # Dump full data for inspection
        puts "Index Data: #{data.inspect}"

        # Verify key statistics
        assert data[:current_fiscal_year].present?
        assert data[:total_users_count].present? # Need to add users to setup for this
        assert data[:ytd_constituents_count].present? # Need to add constituents to setup for this
        assert data[:open_applications_count].present? # Need to verify what 'open' means
        assert data[:pending_services_count].present? # Need to add services/training sessions for this

        # Verify application counts (based on new setup)
        # The service initializes missing counts to 0 (not nil)
        assert_equal status_counts.fetch(Application.statuses[:draft], 0), data[:draft_count]
        assert_equal status_counts.fetch(Application.statuses[:in_progress], 0), data[:in_progress_count]
        assert_equal status_counts.fetch(Application.statuses[:needs_information], 0), data[:in_review_count] # Map "in_review" count to "needs_information"
        assert_equal status_counts.fetch(Application.statuses[:approved], 0), data[:approved_count]
      end
    end

    test 'handles errors gracefully' do
      # Set up applications with known dates
      current_fy_year = Date.current.month >= 7 ? Date.current.year : Date.current.year - 1
      current_fy_start = Date.new(current_fy_year, 7, 1)
      previous_fy_start = Date.new(current_fy_year - 1, 7, 1)

      # Create applications with specific statuses and dates for reporting tests
      # 1 Draft application
      draft_app = create(:application, created_at: current_fy_start + 1.month, status: :draft)

      # 2 In-progress applications (submitted by constituent)
      submitted_app1 = create(:application, created_at: current_fy_start + 2.months, status: :in_progress)
      submitted_app2 = create(:application, created_at: current_fy_start + 3.months, status: :in_progress)

      # 0 In Review applications (not created)

      # 3 Approved applications (2 current FY, 1 previous FY)
      approved_app1 = create(:application, created_at: current_fy_start + 4.months, status: :approved)
      approved_app2 = create(:application, created_at: current_fy_start + 5.months, status: :approved) # Added another approved app in current FY
      approved_app3 = create(:application, created_at: previous_fy_start + 1.month, status: :approved) # Previous FY

      # Set up mocks for ActiveStorage attachments to prevent byte_size() errors
      setup_attachment_mocks_for_audit_logs

      with_mocked_attachments do
        # Mock Application.where to raise an exception
        Application.stub :where, ->(*_args) { raise StandardError, 'Test error' } do
          service = ReportingService.new

          # Check dashboard data
          data = service.generate_dashboard_data
          assert_empty data
          assert_includes service.errors, 'Error generating dashboard data: Test error'

          # Check index data
          data = service.generate_index_data
          assert_empty data
          assert_includes service.errors, 'Error generating index data: Test error'
        end
      end
    end
  end
end
