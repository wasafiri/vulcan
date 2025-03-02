require "test_helper"

module ConstituentPortal
  class ApplicationsDisabilityTest < ActionDispatch::IntegrationTest
    setup do
      @constituent = users(:constituent_john)
      sign_in(@constituent)

      @application_params = {
        application: {
          household_size: 2,
          annual_income: "50000",
          maryland_resident: "1",
          self_certify_disability: "1",
          medical_provider_name: "Dr. Smith",
          medical_provider_phone: "555-123-4567",
          medical_provider_email: "dr.smith@example.com",
          # No disabilities selected initially
          hearing_disability: "0",
          vision_disability: "0",
          speech_disability: "0",
          mobility_disability: "0",
          cognition_disability: "0"
        }
      }
    end

    test "should not create application when submitting with no disabilities" do
      skip "Skipping due to authentication issues in integration tests"
      # Ensure constituent has no disabilities
      @constituent.update(
        hearing_disability: false,
        vision_disability: false,
        speech_disability: false,
        mobility_disability: false,
        cognition_disability: false
      )

      assert_no_difference "Application.count" do
        post constituent_portal_applications_path, params: @application_params.merge(submit_application: true)
      end

      assert_response :unprocessable_entity
      assert_match /At least one disability must be selected/, response.body
    end

    test "should create application when submitting with one disability" do
      skip "Skipping due to authentication issues in integration tests"
      # Set one disability in the params
      @application_params[:application][:hearing_disability] = "1"

      assert_difference "Application.count", 1 do
        post constituent_portal_applications_path, params: @application_params.merge(submit_application: true)
      end

      assert_redirected_to constituent_portal_application_path(Application.last)
      assert @constituent.reload.hearing_disability
      assert_equal "in_progress", Application.last.status
    end

    test "should create application when submitting with multiple disabilities" do
      skip "Skipping due to authentication issues in integration tests"
      # Set multiple disabilities in the params
      @application_params[:application][:hearing_disability] = "1"
      @application_params[:application][:vision_disability] = "1"
      @application_params[:application][:mobility_disability] = "1"

      assert_difference "Application.count", 1 do
        post constituent_portal_applications_path, params: @application_params.merge(submit_application: true)
      end

      assert_redirected_to constituent_portal_application_path(Application.last)
      assert @constituent.reload.hearing_disability
      assert @constituent.reload.vision_disability
      assert @constituent.reload.mobility_disability
      assert_equal "in_progress", Application.last.status
    end

    test "should save draft application even with no disabilities" do
      skip "Skipping due to authentication issues in integration tests"
      assert_difference "Application.count", 1 do
        post constituent_portal_applications_path, params: @application_params
      end

      assert_redirected_to constituent_portal_application_path(Application.last)
      assert_equal "draft", Application.last.status
    end

    test "should update application when adding disabilities" do
      skip "Skipping due to authentication issues in integration tests"
      # First create a draft application
      post constituent_portal_applications_path, params: @application_params
      application = Application.last

      # Now update with disabilities and submit
      put constituent_portal_application_path(application), params: {
        application: {
          hearing_disability: "1",
          vision_disability: "1"
        },
        submit_application: true
      }

      assert_redirected_to constituent_portal_application_path(application)
      assert @constituent.reload.hearing_disability
      assert @constituent.reload.vision_disability
      assert_equal "in_progress", application.reload.status
    end

    test "should properly process all disability types" do
      skip "Skipping due to authentication issues in integration tests"
      # Test each disability type individually
      disability_types = [ :hearing, :vision, :speech, :mobility, :cognition ]

      disability_types.each do |disability_type|
        # Reset all disabilities
        @constituent.update(
          hearing_disability: false,
          vision_disability: false,
          speech_disability: false,
          mobility_disability: false,
          cognition_disability: false
        )

        # Create params with just this disability
        params = @application_params.dup
        params[:application]["#{disability_type}_disability"] = "1"

        post constituent_portal_applications_path, params: params.merge(submit_application: true)

        assert_redirected_to constituent_portal_application_path(Application.last)
        assert @constituent.reload.send("#{disability_type}_disability"),
               "#{disability_type}_disability should be true after submission"
      end
    end

    test "should handle disability validation when transitioning from draft to submitted" do
      skip "Skipping due to authentication issues in integration tests"
      # Create a draft application first
      post constituent_portal_applications_path, params: @application_params
      application = Application.last
      assert_equal "draft", application.status

      # Try to submit without disabilities
      put constituent_portal_application_path(application), params: {
        application: { household_size: 3 },
        submit_application: true
      }

      assert_response :unprocessable_entity
      assert_match /At least one disability must be selected/, response.body

      # Now add a disability and try again
      put constituent_portal_application_path(application), params: {
        application: {
          household_size: 3,
          cognition_disability: "1"
        },
        submit_application: true
      }

      assert_redirected_to constituent_portal_application_path(application)
      assert @constituent.reload.cognition_disability
      assert_equal "in_progress", application.reload.status
    end
  end
end
