# frozen_string_literal: true

require 'test_helper'

module ConstituentPortal
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    include AuthenticationTestHelper # Ensure helper methods are available

    setup do
      @user = create(:constituent, :with_disabilities) # Use the :constituent factory
      sign_in_with_headers(@user) # Use helper for integration tests
    end

    test 'should get show' do
      # Assuming the dashboard show page is the root for the constituent portal
      get constituent_portal_dashboard_path
      assert_response :success
    end

    test 'dashboard shows correct application status for constituent' do
      create(:application, user: @user, status: :in_progress)

      get constituent_portal_dashboard_path
      assert_response :success
      # Assert for the status badge text using a more specific selector
      assert_select 'div.flex.items-center span.rounded-full', text: 'In progress'
    end

    test 'dashboard shows different content based on application status' do
      # Test for a status that might require user action, e.g., needs_information
      create(:application, user: @user, status: :needs_information)

      get constituent_portal_dashboard_path
      assert_response :success
      # Assert for the status badge text and the view details link
      assert_select 'div.flex.items-center span.rounded-full', text: 'Needs information'
      assert_select 'a', text: 'View Application Details'
    end
  end
end
