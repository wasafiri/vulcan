require 'test_helper'

module Applications
  class ReportingServiceTest < ActiveSupport::TestCase
    setup do
      # Create some test data
      @admin = users(:admin)
      @user = users(:confirmed_user)
      
      # Set up applications with known dates
      @current_fy_year = Date.current.month >= 7 ? Date.current.year : Date.current.year - 1
      @current_fy_start = Date.new(@current_fy_year, 7, 1)
      @previous_fy_start = Date.new(@current_fy_year - 1, 7, 1)
      
      # Set up current fiscal year applications
      @current_app1 = applications(:active)
      prepare_application_for_test(@current_app1, 
                                  status: 'approved', 
                                  income_proof_status: 'approved',
                                  residency_proof_status: 'approved')
      @current_app1.update!(created_at: @current_fy_start + 1.month)
      
      @current_app2 = applications(:in_review)
      prepare_application_for_test(@current_app2, status: 'draft')
      @current_app2.update!(created_at: @current_fy_start + 2.months)
      
      # Set up previous fiscal year applications
      @previous_app = applications(:complete)
      prepare_application_for_test(@previous_app, 
                                  status: 'approved', 
                                  income_proof_status: 'approved',
                                  residency_proof_status: 'approved')
      @previous_app.update!(created_at: @previous_fy_start + 1.month)
      
      # Create some vouchers
      @current_voucher = Voucher.create!(
        status: 'active',
        initial_value: 100,
        current_value: 100,
        application: @current_app1,
        created_at: @current_fy_start + 1.month
      )
      
      @previous_voucher = Voucher.create!(
        status: 'redeemed',
        initial_value: 200,
        current_value: 0,
        application: @previous_app,
        created_at: @previous_fy_start + 1.month
      )
    end
    
    test "generates dashboard data with correct fiscal year information" do
      service = ReportingService.new
      data = service.generate_dashboard_data
      
      # Verify fiscal year data
      assert_equal @current_fy_year, data[:current_fy]
      assert_equal @current_fy_year - 1, data[:previous_fy]
      
      # Verify date ranges
      assert_equal @current_fy_start, data[:current_fy_start]
      assert_equal Date.new(@current_fy_year + 1, 6, 30), data[:current_fy_end]
      assert_equal @previous_fy_start, data[:previous_fy_start]
      assert_equal Date.new(@current_fy_year, 6, 30), data[:previous_fy_end]
    end
    
    test "counts applications correctly" do
      service = ReportingService.new
      data = service.generate_dashboard_data
      
      # Verify application counts
      assert_equal 2, data[:current_fy_applications]
      assert_equal 1, data[:previous_fy_applications]
      
      # Verify draft applications count
      assert_equal 1, data[:current_fy_draft_applications]
      assert_equal 0, data[:previous_fy_draft_applications]
    end
    
    test "counts vouchers correctly" do
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
    
    test "includes chart data in dashboard" do
      service = ReportingService.new
      data = service.generate_dashboard_data
      
      # Verify chart data exists
      assert data[:applications_chart_data].present?
      assert data[:vouchers_chart_data].present?
      assert data[:services_chart_data].present?
      assert data[:mfr_chart_data].present?
      
      # Verify specific chart data
      assert_equal 2, data[:applications_chart_data][:current]["Applications"]
      assert_equal 1, data[:applications_chart_data][:previous]["Applications"]
    end
    
    test "allows fiscal year override" do
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
    
    test "generates index data with required statistics" do
      service = ReportingService.new
      data = service.generate_index_data
      
      # Verify key statistics
      assert data[:current_fiscal_year].present?
      assert data[:total_users_count].present?
      assert data[:ytd_constituents_count].present?
      assert data[:open_applications_count].present?
      assert data[:pending_services_count].present?
      
      # Verify chart data
      assert data[:pipeline_chart_data].present?
      assert data[:status_chart_data].present?
      
      # Verify application counts
      assert_equal 1, data[:draft_count]
      assert_equal 2, data[:submitted_count]
      assert_equal 0, data[:in_review_count]
      assert_equal 2, data[:approved_count]
    end
    
    test "handles errors gracefully" do
      # Mock Application.where to raise an exception
      Application.stub :where, ->(*_args) { raise StandardError, "Test error" } do
        service = ReportingService.new
        
        # Check dashboard data
        data = service.generate_dashboard_data
        assert_empty data
        assert_includes service.errors, "Error generating dashboard data: Test error"
        
        # Check index data
        data = service.generate_index_data
        assert_empty data
        assert_includes service.errors, "Error generating index data: Test error"
      end
    end
  end
end
