# frozen_string_literal: true

require 'test_helper'

module ConstituentPortal
  class GuardianApplicationsTest < ActionDispatch::IntegrationTest
    include ActionDispatch::TestProcess::FixtureFile

    setup do
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
      sign_in(@guardian_user)

      @valid_pdf = fixture_file_upload('test/fixtures/files/income_proof.pdf', 'application/pdf')
      @valid_image = fixture_file_upload('test/fixtures/files/residency_proof.pdf', 'application/pdf')

      # Set thread local context to skip proof validations in tests
      Thread.current[:paper_application_context] = true
    end

    teardown do
      # Clean up thread local context after each test
      Thread.current[:paper_application_context] = nil
    end

    test 'should create application for a dependent' do
      # Verify the relationship exists before the test
      assert @guardian_user.dependents.include?(@dependent_user), 'Guardian should have dependent in their dependents collection'

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

      # Debug information if application creation fails
      application = Application.last

      if application.nil?
        puts "Application creation failed. Response status: #{response.status}"
        puts "Response body: #{response.body}" if response.status >= 400
        puts "Total applications in DB: #{Application.count}"
        puts "Guardian user ID: #{@guardian_user.id}"
        puts "Dependent user ID: #{@dependent_user.id}"
        puts "Guardian dependents: #{@guardian_user.dependents.pluck(:id)}"
        flunk 'Application was not created'
      end

      # Verify we get redirected to the application page
      assert_redirected_to constituent_portal_application_path(application)

      # Verify application was created successfully
      assert_equal 'in_progress', application.status
      assert_equal @dependent_user.id, application.user_id # Application is for the dependent
      assert_equal @guardian_user.id, application.managing_guardian_id # Guardian is the managing guardian

      # Verify dependent user's disability was updated (if applicable via form)
      @dependent_user.reload
      assert @dependent_user.hearing_disability

      # Verify at least one event was created (the application_created event)
      created_event = Event.find_by(action: 'application_created')
      assert_not_nil created_event
      assert_equal @guardian_user.id, created_event.user_id # Event logged by the guardian
      assert_equal application.id, created_event.metadata['application_id']
      assert_equal 'online', created_event.metadata['submission_method']
    end
  end
end
