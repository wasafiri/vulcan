# frozen_string_literal: true

require 'application_system_test_case'

module VendorPortal
  class DashboardTest < ApplicationSystemTestCase
    setup do
      @vendor = create(:vendor, :approved)
      sign_in(@vendor)
    end

    test 'chart has proper accessibility attributes' do
      visit vendor_dashboard_path

      # Check that the table has proper accessibility attributes
      assert_selector "table#monthly-totals-table[aria-labelledby='monthly-totals-heading']"
      assert_selector 'table#monthly-totals-table caption.sr-only'

      # Check that the chart description is present
      assert_selector '#chart-description.sr-only'

      # Check that the toggle button has proper accessibility attributes
      assert_selector "button[data-chart-toggle-target='button']"

      # Check that the chart container has an ID for ARIA controls (it's hidden by default)
      assert_selector '#monthly-totals-chart', visible: :all
    end
  end
end
