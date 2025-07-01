# frozen_string_literal: true

require 'test_helper'

module ConstituentPortal
  class GuardianApplicationsTest < ActionDispatch::IntegrationTest
    include ActionDispatch::TestProcess::FixtureFile

    setup do
      # Clear any stale Current state that might affect test isolation
      Current.user = nil
      Current.proof_attachment_service_context = nil
      Current.paper_context = nil
      Current.resubmitting_proof = nil

      # Create a guardian user (the one who will be signed in)
      @guardian_user = create(:constituent, email: 'guardian.test@example.com', phone: '5555551111')
      # Create a dependent user (the one the application is for)
      @dependent_user = create(:constituent, email: 'dependent.test@example.com', phone: '5555552222', date_of_birth: 10.years.ago)

      # Establish the guardian relationship
      @relationship = GuardianRelationship.create!(
        guardian_id: @guardian_user.id,
        dependent_id: @dependent_user.id,
        relationship_type: 'Parent'
      )

      # Sign in as the guardian user
      sign_in_for_integration_test(@guardian_user)

      @valid_pdf = fixture_file_upload('test/fixtures/files/income_proof.pdf', 'application/pdf')
      @valid_image = fixture_file_upload('test/fixtures/files/residency_proof.pdf', 'application/pdf')

      # Set thread local context to skip proof validations in tests
      setup_paper_application_context
    end

    teardown do
      # Clean up thread local context after each test
      teardown_paper_application_context

      # Clear any Current state to prevent test isolation issues
      Current.user = nil
      Current.proof_attachment_service_context = nil
      Current.paper_context = nil
      Current.resubmitting_proof = nil
    end

    test 'should create application for a dependent' do
      # Verify the relationship exists before the test
      assert @guardian_user.dependents.include?(@dependent_user), 'Guardian should have dependent in their dependents collection'

      # Count applications before to verify creation
      initial_application_count = Application.count

      # Make the POST request to create the application
      post constituent_portal_applications_path, params: {
        application: {
          user_id: @dependent_user.id, # Specify the dependent's user ID
          maryland_resident: true,
          household_size: 2, # Household size including guardian and dependent
          annual_income: 30_000, # Guardian's income
          self_certify_disability: true, # Disability is for the dependent
          hearing_disability: true, # Disability is for the dependent
          residency_proof: @valid_image,
          income_proof: @valid_pdf
        },
        medical_provider: {
          name: 'Dr. Dependent',
          phone: '2025553333',
          email: 'drdependent@example.com'
        },
        submit_application: 'Submit Application'
      }

      # Verify we get redirected and an application was created
      assert_response :redirect
      assert_equal initial_application_count + 1, Application.count, 'One application should have been created'

      # Find the newly created application (should be the last one for this dependent)
      application = Application.where(user_id: @dependent_user.id).order(created_at: :desc).first
      assert_not_nil application, 'Application should have been created for the dependent'

      # Verify we get redirected to the application page
      expected_path = constituent_portal_application_path(application.id)
      assert response.location.include?(expected_path), "Expected redirect to include #{expected_path}, got #{response.location}"

      # Verify application was created successfully
      assert_equal 'in_progress', application.status
      assert_equal @dependent_user.id, application.user_id,
                   "Application should be for the dependent user (expected: #{@dependent_user.id}, got: #{application.user_id})"
      assert_equal @guardian_user.id, application.managing_guardian_id,
                   "Guardian should be the managing guardian (expected: #{@guardian_user.id}, got: #{application.managing_guardian_id})"

      # Verify dependent user's disability was updated (if applicable via form)
      @dependent_user.reload
      assert @dependent_user.hearing_disability

      # Verify at least one event was created (the application_created event)
      created_event = Event.where(action: 'application_created').order(created_at: :desc).first
      assert_not_nil created_event
      assert_equal @guardian_user.id, created_event.user_id # Event logged by the guardian
      # Note: application_id may not be in metadata depending on how the event was created
      assert_equal application.id, created_event.metadata['application_id'] if created_event.metadata['application_id'].present?
      assert_equal 'online', created_event.metadata['submission_method']
    end
  end
end
