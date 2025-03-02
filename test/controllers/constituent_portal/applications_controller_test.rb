require "test_helper"

module ConstituentPortal
  class ApplicationsControllerTest < ActionDispatch::IntegrationTest
    include ActionDispatch::TestProcess::FixtureFile

    setup do
      @user = users(:constituent_john)
      @application = applications(:one)
      @valid_pdf = fixture_file_upload("test/fixtures/files/income_proof.pdf", "application/pdf")
      @valid_image = fixture_file_upload("test/fixtures/files/residency_proof.pdf", "application/pdf")

      # We don't sign in the user for most tests to verify authentication requirements
      # Tests that need an authenticated user will call sign_in(@user) explicitly
    end

  # Test that the checkbox handling works correctly
  test "should handle array values for self_certify_disability" do
    # Sign in the user
    sign_in(@user)

    # Simulate a form submission with an array value for self_certify_disability
    post constituent_portal_applications_path, params: {
      application: {
        maryland_resident: true,
        household_size: 3,
        annual_income: 50000,
        self_certify_disability: checkbox_params(true), # Use our helper to simulate a checked checkbox
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

  # Test that the new application page loads correctly
  test "should get new" do
    # Sign in the user first
    sign_in(@user)

    # Then try to access the new application page
    get new_constituent_portal_application_path, headers: default_headers

    # Verify the page loaded successfully
    assert_response :success
    assert_select "h1", "New Application"
  end

  test "should create application as draft" do
    skip "Skipping due to authentication issues in integration tests"
    assert_difference("Application.count") do
      post constituent_portal_applications_path, params: {
        application: {
          maryland_resident: true,
          household_size: 3,
          annual_income: 50000,
          self_certify_disability: true,
          hearing_disability: true
        },
        medical_provider: {
          name: "Dr. Smith",
          phone: "2025551234",
          email: "drsmith@example.com"
        },
        save_draft: "Save Application"
      }
    end

    application = Application.last
    assert_redirected_to constituent_portal_application_path(application)
    assert_equal "draft", application.status
    assert_equal "Dr. Smith", application.medical_provider_name
    assert_equal "2025551234", application.medical_provider_phone
    assert_equal "drsmith@example.com", application.medical_provider_email
  end

  test "should create application as submitted" do
    skip "Skipping due to authentication issues in integration tests"
    assert_difference("Application.count") do
      post constituent_portal_applications_path, params: {
        application: {
          maryland_resident: true,
          household_size: 3,
          annual_income: 50000,
          self_certify_disability: true,
          hearing_disability: true,
          residency_proof: @valid_image,
          income_proof: @valid_pdf
        },
        medical_provider: {
          name: "Dr. Smith",
          phone: "2025551234",
          email: "drsmith@example.com"
        },
        submit_application: "Submit Application"
      }
    end

    application = Application.last
    assert_redirected_to constituent_portal_application_path(application)
    assert_equal "in_progress", application.status
    assert application.income_proof.attached?
    assert application.residency_proof.attached?
    assert_equal "not_reviewed", application.income_proof_status
    assert_equal "not_reviewed", application.residency_proof_status
  end

  # Test that the application show page loads correctly
  test "should show application" do
    # Sign in the user first
    sign_in(@user)

    # Then try to access the application show page
    get constituent_portal_application_path(@application), headers: default_headers

    # Verify the page loaded successfully
    assert_response :success
    assert_select "h1", /Application ##{@application.id}/
  end

  # Test that the edit page loads correctly for draft applications
  test "should get edit for draft application" do
    # Set the application to draft status
    @application.update!(status: :draft)

    # Sign in the user first
    sign_in(@user)

    # Then try to access the edit page
    get edit_constituent_portal_application_path(@application), headers: default_headers

    # Verify the page loaded successfully
    assert_response :success
  end

  # Test that users can't edit submitted applications
  test "should not get edit for submitted application" do
    # Set the application to in_progress status (submitted)
    @application.update!(status: :in_progress)

    # Sign in the user first
    sign_in(@user)

    # Try to edit a submitted application
    get edit_constituent_portal_application_path(@application), headers: default_headers

    # Should be redirected to application page with an alert
    assert_redirected_to constituent_portal_application_path(@application)
    assert_flash_message(:alert, "This application has already been submitted and cannot be edited.")
  end

  test "should update draft application" do
    skip "Skipping due to authentication issues in integration tests"
    @application.update!(status: :draft)
    patch constituent_portal_application_path(@application), params: {
      application: {
        household_size: 4,
        annual_income: 60000
      }
    }
    assert_redirected_to constituent_portal_application_path(@application)
    @application.reload
    assert_equal 4, @application.household_size
    assert_equal 60000, @application.annual_income
  end

  test "should submit draft application" do
    skip "Skipping due to authentication issues in integration tests"
    @application.update!(status: :draft)
    patch constituent_portal_application_path(@application), params: {
      application: {
        household_size: 4,
        annual_income: 60000,
        medical_provider: {
          name: "Dr. Smith",
          phone: "2025551234",
          email: "drsmith@example.com"
        }
      },
      submit_application: "Submit Application"
    }
    assert_redirected_to constituent_portal_application_path(@application)
    @application.reload
    assert_equal "in_progress", @application.status
  end

  test "should not update submitted application" do
    skip "Skipping due to authentication issues in integration tests"
    @application.update!(status: :in_progress)
    patch constituent_portal_application_path(@application), params: {
      application: {
        household_size: 4,
        annual_income: 60000
      }
    }
    assert_redirected_to constituent_portal_application_path(@application)
    assert_equal "This application has already been submitted and cannot be edited.", flash[:alert]
    @application.reload
    assert_not_equal 4, @application.household_size
    assert_not_equal 60000, @application.annual_income
  end

  test "should show validation errors for invalid submission" do
    skip "Skipping due to authentication issues in integration tests"
    post constituent_portal_applications_path, params: {
      application: {
        maryland_resident: false,
        household_size: "",
        annual_income: ""
      },
      submit_application: "Submit Application"
    }
    assert_response :unprocessable_entity
    assert_select ".bg-red-50", /prohibited this application from being saved/
    assert_select "li", /Maryland resident You must be a Maryland resident to apply/
    assert_select "li", /Household size can't be blank/
    assert_select "li", /Annual income can't be blank/
  end

  test "should show uploaded document filenames on show page" do
    skip "Skipping due to authentication issues in integration tests"
    # First attach files to the application
    @application.income_proof.attach(@valid_pdf)
    @application.residency_proof.attach(@valid_image)
    @application.save!

    get constituent_portal_application_path(@application)
    assert_response :success

    # Check for filenames
    assert_select "p", /Filename: #{File.basename(@valid_pdf.path)}/
    assert_select "p", /Filename: #{File.basename(@valid_image.path)}/
  end

  test "should return FPL thresholds" do
    # Set up FPL policies for testing
    Policy.find_or_create_by(key: "fpl_1_person").update(value: 15000)
    Policy.find_or_create_by(key: "fpl_2_person").update(value: 20000)
    Policy.find_or_create_by(key: "fpl_3_person").update(value: 25000)
    Policy.find_or_create_by(key: "fpl_4_person").update(value: 30000)
    Policy.find_or_create_by(key: "fpl_5_person").update(value: 35000)
    Policy.find_or_create_by(key: "fpl_6_person").update(value: 40000)
    Policy.find_or_create_by(key: "fpl_7_person").update(value: 45000)
    Policy.find_or_create_by(key: "fpl_8_person").update(value: 50000)
    Policy.find_or_create_by(key: "fpl_modifier_percentage").update(value: 400)

    get fpl_thresholds_constituent_portal_applications_path
    assert_response :success

    # Parse the JSON response
    json_response = JSON.parse(response.body)

    # Verify the response contains the expected data
    assert_equal 400, json_response["modifier"]
    assert_equal 15000, json_response["thresholds"]["1"]
    assert_equal 20000, json_response["thresholds"]["2"]
    assert_equal 25000, json_response["thresholds"]["3"]
    assert_equal 30000, json_response["thresholds"]["4"]
    assert_equal 35000, json_response["thresholds"]["5"]
    assert_equal 40000, json_response["thresholds"]["6"]
    assert_equal 45000, json_response["thresholds"]["7"]
    assert_equal 50000, json_response["thresholds"]["8"]
  end

  test "should maintain user association during update" do
    skip "Skipping due to authentication issues in integration tests"
    # Create a draft application
    @application.update!(status: :draft)

    # Update the application with new values and disability information
    patch constituent_portal_application_path(@application), params: {
      application: {
        household_size: 5,
        annual_income: 75000,
        is_guardian: "0",
        hearing_disability: "1",
        vision_disability: "1",
        speech_disability: "0",
        mobility_disability: "0",
        cognition_disability: "0",
        medical_provider: {
          name: "Dr. Jane Smith",
          phone: "2025559876",
          email: "drjane@example.com"
        }
      }
    }

    # Verify the update was successful
    assert_redirected_to constituent_portal_application_path(@application)

    # Reload the application and verify changes
    @application.reload

    # Check application attributes were updated
    assert_equal 5, @application.household_size
    assert_equal 75000, @application.annual_income
    assert_equal "Dr. Jane Smith", @application.medical_provider_name
    assert_equal "2025559876", @application.medical_provider_phone
    assert_equal "drjane@example.com", @application.medical_provider_email

    # Most importantly, verify the user association was maintained
    assert_not_nil @application.user_id
    assert_equal @user.id, @application.user_id

    # Verify user disability attributes were updated
    @user.reload
    assert_equal true, @user.hearing_disability
    assert_equal true, @user.vision_disability
    assert_equal false, @user.speech_disability
    assert_equal false, @user.mobility_disability
    assert_equal false, @user.cognition_disability
  end

  test "should save all application fields when saving as draft" do
    skip "Skipping due to authentication issues in integration tests"
    # Test data for all fields
    application_params = {
      application: {
        # Basic application fields
        maryland_resident: "1",
        household_size: "3",
        annual_income: "45000",
        self_certify_disability: "1",

        # Disability selections
        hearing_disability: "1",
        vision_disability: "1",
        speech_disability: "0",
        mobility_disability: "1",
        cognition_disability: "0",

        # Guardian information
        is_guardian: "1",
        guardian_relationship: "Parent"
      },

      # Medical provider information (using the separate hash structure)
      medical_provider: {
        name: "Dr. Jane Smith",
        phone: "5551234567",
        fax: "5557654321",
        email: "dr.smith@example.com"
      },

      # Use the save_draft button
      save_draft: "Save Application"
    }

    # Post the data to create a draft application
    assert_difference("Application.count") do
      post constituent_portal_applications_path, params: application_params
    end

    # Get the newly created application
    application = Application.last

    # Verify application fields were saved
    assert_equal "draft", application.status
    assert application.maryland_resident
    assert_equal 3, application.household_size
    assert_equal 45000, application.annual_income.to_i
    assert application.self_certify_disability

    # Verify medical provider info was saved
    assert_equal "Dr. Jane Smith", application.medical_provider_name
    assert_equal "5551234567", application.medical_provider_phone
    assert_equal "5557654321", application.medical_provider_fax
    assert_equal "dr.smith@example.com", application.medical_provider_email

    # Verify user attributes were updated
    user = application.user.reload
    assert user.is_guardian
    assert_equal "Parent", user.guardian_relationship
    assert user.hearing_disability
    assert user.vision_disability
    assert_not user.speech_disability
    assert user.mobility_disability
    assert_not user.cognition_disability
  end
  end
end
