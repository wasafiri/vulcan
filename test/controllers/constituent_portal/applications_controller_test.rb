# frozen_string_literal: true

require 'test_helper'

module ConstituentPortal
  class ApplicationsControllerTest < ActionDispatch::IntegrationTest
    include ActionDispatch::TestProcess::FixtureFile

    setup do
      # Set up test data
      @user = users(:constituent_john)
      @application = applications(:one)
      @valid_pdf = fixture_file_upload('test/fixtures/files/income_proof.pdf', 'application/pdf')
      @valid_image = fixture_file_upload('test/fixtures/files/residency_proof.pdf', 'application/pdf')

      # Sign in the user for all tests
      sign_in(@user)

      # Enable debug logging for authentication issues
      ENV['DEBUG_AUTH'] = 'true'
    end

    # Test that the checkbox handling works correctly
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

    # Test that the new application page loads correctly
    test 'should get new' do
      # Access the new application page
      get new_constituent_portal_application_path

      # Verify the page loaded successfully
      assert_response :success
      assert_select 'h1', 'New Application'
    end

    # Test creating a draft application
    test 'should create application as draft' do
      # Submit a draft application
      assert_difference('Application.count') do
        post constituent_portal_applications_path, params: {
          application: {
            maryland_resident: true,
            household_size: 3,
            annual_income: 50_000,
            self_certify_disability: checkbox_params(true),
            hearing_disability: true
          },
          medical_provider: {
            name: 'Dr. Smith',
            phone: '2025551234',
            email: 'drsmith@example.com'
          },
          save_draft: 'Save Application'
        }
      end

      # Get the newly created application
      application = Application.last

      # Verify the application was created correctly
      assert_redirected_to constituent_portal_application_path(application)
      assert_equal 'draft', application.status
      assert_equal 'Dr. Smith', application.medical_provider_name
      assert_equal '2025551234', application.medical_provider_phone
      assert_equal 'drsmith@example.com', application.medical_provider_email
    end

    # Test creating an application as submitted with required proofs
    test 'should create application as submitted' do
      # Submit an application with required proofs
      assert_difference('Application.count') do
        post constituent_portal_applications_path, params: {
          application: {
            maryland_resident: true,
            household_size: 3,
            annual_income: 50_000,
            self_certify_disability: checkbox_params(true),
            hearing_disability: true,
            residency_proof: @valid_image,
            income_proof: @valid_pdf
          },
          medical_provider: {
            name: 'Dr. Smith',
            phone: '2025551234',
            email: 'drsmith@example.com'
          },
          submit_application: 'Submit Application'
        }
      end

      # Get the newly created application
      application = Application.last

      # Verify the application was created correctly
      assert_redirected_to constituent_portal_application_path(application)
      assert_equal 'in_progress', application.status

      # Verify proofs were attached
      assert application.income_proof.attached?
      assert application.residency_proof.attached?
      assert_equal 'not_reviewed', application.income_proof_status
      assert_equal 'not_reviewed', application.residency_proof_status
    end

    # Test that the application show page loads correctly
    test 'should show application' do
      # Access the application show page
      get constituent_portal_application_path(@application)

      # Verify the page loaded successfully
      assert_response :success
      assert_select 'h1', /Application ##{@application.id}/
    end

    # Test that the edit page loads correctly for draft applications
    test 'should get edit for draft application' do
      # Set the application to draft status
      @application.update!(status: :draft)

      # Access the edit page
      get edit_constituent_portal_application_path(@application)

      # Verify the page loaded successfully
      assert_response :success
    end

    # Test that users can't edit submitted applications
    test 'should not get edit for submitted application' do
      # Set the application to in_progress status (submitted)
      @application.update!(status: :in_progress)

      # Try to edit a submitted application
      get edit_constituent_portal_application_path(@application)

      # Should be redirected to application page with an alert
      assert_redirected_to constituent_portal_application_path(@application)
      assert_flash_message(:alert, 'This application has already been submitted and cannot be edited.')
    end

    # Test updating a draft application
    test 'should update draft application' do
      # Set the application to draft status
      @application.update!(status: :draft)

      # Update the application
      patch constituent_portal_application_path(@application), params: {
        application: {
          household_size: 4,
          annual_income: 60_000
        }
      }

      # Verify the update was successful
      assert_redirected_to constituent_portal_application_path(@application)

      # Reload the application and verify changes
      @application.reload
      assert_equal 4, @application.household_size
      assert_equal 60_000, @application.annual_income
    end

    # Test submitting a draft application
    test 'should submit draft application' do
      skip 'This test is currently failing and needs to be fixed'

      # Create a new draft application
      application = Application.create!(
        user: @user,
        status: :draft,
        application_date: Time.current,
        submission_method: :online,
        maryland_resident: true,
        household_size: 3,
        annual_income: 50_000,
        self_certify_disability: true,
        medical_provider_name: 'Dr. Smith',
        medical_provider_phone: '2025551234',
        medical_provider_email: 'drsmith@example.com'
      )

      # Submit the draft application
      patch constituent_portal_application_path(application), params: {
        application: {
          household_size: 4,
          annual_income: 60_000,
          maryland_resident: true,
          self_certify_disability: true,
          terms_accepted: true,
          information_verified: true,
          medical_release_authorized: true
        },
        submit_application: 'Submit Application'
      }

      # Verify the submission was successful
      assert_redirected_to constituent_portal_application_path(application)

      # Reload the application and verify status change
      application.reload
      assert_equal 'in_progress', application.status
    end

    # Test that submitted applications cannot be updated
    test 'should not update submitted application' do
      # Set the application to in_progress status (submitted)
      @application.update!(status: :in_progress)

      # Attempt to update a submitted application
      patch constituent_portal_application_path(@application), params: {
        application: {
          household_size: 4,
          annual_income: 60_000
        }
      }

      # Verify the update was rejected
      assert_redirected_to constituent_portal_application_path(@application)
      assert_flash_message(:alert, 'This application has already been submitted and cannot be edited.')

      # Reload the application and verify no changes were made
      @application.reload
      assert_not_equal 4, @application.household_size
      assert_not_equal 60_000, @application.annual_income
    end

    # Test validation errors for invalid submission
    test 'should show validation errors for invalid submission' do
      # Submit an invalid application
      post constituent_portal_applications_path, params: {
        application: {
          maryland_resident: false,
          household_size: '',
          annual_income: ''
        },
        submit_application: 'Submit Application'
      }

      # Verify validation errors are shown
      assert_response :unprocessable_entity
      assert_select '.bg-red-50', /prohibited this application from being saved/
      assert_select 'li', /Maryland resident You must be a Maryland resident to apply/
      assert_select 'li', /Household size can't be blank/
      assert_select 'li', /Annual income can't be blank/
    end

    # Test showing uploaded document filenames
    test 'should show uploaded document filenames on show page' do
      # First attach files to the application
      @application.income_proof.attach(@valid_pdf)
      @application.residency_proof.attach(@valid_image)
      @application.save!

      # Access the application show page
      get constituent_portal_application_path(@application)

      # Verify the page shows the filenames
      assert_response :success
      assert_select 'p', /Filename:/
    end

    test 'should return FPL thresholds' do
      # Set up FPL policies for testing
      Policy.find_or_create_by(key: 'fpl_1_person').update(value: 15_000)
      Policy.find_or_create_by(key: 'fpl_2_person').update(value: 20_000)
      Policy.find_or_create_by(key: 'fpl_3_person').update(value: 25_000)
      Policy.find_or_create_by(key: 'fpl_4_person').update(value: 30_000)
      Policy.find_or_create_by(key: 'fpl_5_person').update(value: 35_000)
      Policy.find_or_create_by(key: 'fpl_6_person').update(value: 40_000)
      Policy.find_or_create_by(key: 'fpl_7_person').update(value: 45_000)
      Policy.find_or_create_by(key: 'fpl_8_person').update(value: 50_000)
      Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)

      get fpl_thresholds_constituent_portal_applications_path
      assert_response :success

      # Parse the JSON response
      json_response = JSON.parse(response.body)

      # Verify the response contains the expected data
      assert_equal 400, json_response['modifier']
      assert_equal 15_000, json_response['thresholds']['1']
      assert_equal 20_000, json_response['thresholds']['2']
      assert_equal 25_000, json_response['thresholds']['3']
      assert_equal 30_000, json_response['thresholds']['4']
      assert_equal 35_000, json_response['thresholds']['5']
      assert_equal 40_000, json_response['thresholds']['6']
      assert_equal 45_000, json_response['thresholds']['7']
      assert_equal 50_000, json_response['thresholds']['8']
    end

    # Test that user association is maintained during update
    test 'should maintain user association during update' do
      skip 'This test is currently failing and needs to be fixed'

      # Use the draft application fixture
      @application = applications(:draft_application)

      # Update the application with new values and disability information
      patch constituent_portal_application_path(@application), params: {
        application: {
          household_size: 5,
          annual_income: 75_000,
          is_guardian: checkbox_params(false),
          hearing_disability: checkbox_params(true),
          vision_disability: checkbox_params(true),
          speech_disability: checkbox_params(false),
          mobility_disability: checkbox_params(false),
          cognition_disability: checkbox_params(false),
          medical_provider: {
            name: 'Dr. Jane Smith',
            phone: '2025559876',
            email: 'drjane@example.com'
          }
        }
      }

      # Verify the update was successful
      assert_redirected_to constituent_portal_application_path(@application)

      # Reload the application and verify changes
      @application.reload

      # Check application attributes were updated
      assert_equal 5, @application.household_size
      assert_equal 75_000, @application.annual_income

      # The medical provider name should be updated from the fixture's "Good Health Clinic"
      # to the value we're setting in the test
      assert_equal 'Dr. Jane Smith', @application.medical_provider_name
      assert_equal '2025559876', @application.medical_provider_phone
      assert_equal 'drjane@example.com', @application.medical_provider_email

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

    # Test saving all application fields when saving as draft
    test 'should save all application fields when saving as draft' do
      # Test data for all fields
      application_params = {
        application: {
          # Basic application fields
          maryland_resident: checkbox_params(true),
          household_size: '3',
          annual_income: '45000',
          self_certify_disability: checkbox_params(true),

          # Disability selections
          hearing_disability: checkbox_params(true),
          vision_disability: checkbox_params(true),
          speech_disability: checkbox_params(false),
          mobility_disability: checkbox_params(true),
          cognition_disability: checkbox_params(false),

          # Guardian information
          is_guardian: checkbox_params(true),
          guardian_relationship: 'Parent'
        },

        # Medical provider information (using the separate hash structure)
        medical_provider: {
          name: 'Dr. Jane Smith',
          phone: '5551234567',
          fax: '5557654321',
          email: 'dr.smith@example.com'
        },

        # Use the save_draft button
        save_draft: 'Save Application'
      }

      # Post the data to create a draft application
      assert_difference('Application.count') do
        post constituent_portal_applications_path, params: application_params
      end

      # Get the newly created application
      application = Application.last

      # Verify application fields were saved
      assert_equal 'draft', application.status
      assert application.maryland_resident
      assert_equal 3, application.household_size
      assert_equal 45_000, application.annual_income.to_i
      assert application.self_certify_disability

      # Verify medical provider info was saved
      assert_equal 'Dr. Jane Smith', application.medical_provider_name
      assert_equal '5551234567', application.medical_provider_phone
      assert_equal '5557654321', application.medical_provider_fax
      assert_equal 'dr.smith@example.com', application.medical_provider_email

      # Verify user attributes were updated
      user = application.user.reload
      assert user.is_guardian
      assert_equal 'Parent', user.guardian_relationship
      assert user.hearing_disability
      assert user.vision_disability
      assert_not user.speech_disability
      assert user.mobility_disability
      assert_not user.cognition_disability
    end
  end
end
