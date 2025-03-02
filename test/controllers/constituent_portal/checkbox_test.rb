require "test_helper"

module ConstituentPortal
  class CheckboxTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:constituent_john)
      sign_in(@user)
    end

    test "should handle array values for self_certify_disability" do
      # Simulate a form submission with an array value for self_certify_disability
      post constituent_portal_applications_path, params: {
        application: {
          maryland_resident: true,
          household_size: 3,
          annual_income: 50000,
          self_certify_disability: [ "0", "1" ], # Simulate the array that Rails sends
          hearing_disability: true
        },
        medical_provider: {
          name: "Dr. Smith",
          phone: "2025551234",
          email: "drsmith@example.com"
        },
        save_draft: "Save Application"
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
