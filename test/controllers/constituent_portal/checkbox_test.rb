# frozen_string_literal: true

require 'test_helper'

module ConstituentPortal
  class CheckboxTest < ActionDispatch::IntegrationTest
    setup do
      @user = create(:constituent) # Already using factory instead of fixture
      sign_in(@user)
    end

    # Helper method to simulate a checked checkbox that returns an array value
    # This helper was likely missing in the original implementation
    def checkbox_params(value)
      # HTML forms send array values for checked checkboxes
      # This simulates the behavior of a checkbox in HTML form
      value ? ['1'] : ['0']
    end

    test 'should handle array values for self_certify_disability' do
      # Simulate a form submission with an array value for self_certify_disability
      post constituent_portal_applications_path, params: {
        application: {
          maryland_resident: true,
          household_size: 3,
          annual_income: 50_000,
          self_certify_disability: checkbox_params(true), # Use our helper to simulate a checked checkbox
          hearing_disability: true
        },
        medical_provider: {
          name: 'Dr. Smith',
          phone: '2025551234',
          email: 'drsmith@example.com'
        },
        save_draft: 'Save Application'
      }

      # Check that the application was created
      assert_response :redirect

      # Get the newly created application
      application = Application.last

      # Verify that self_certify_disability was correctly cast to true
      assert_equal true, application.self_certify_disability
    end
  end
end
