# frozen_string_literal: true

require 'test_helper'

module Applications
  class FilterServiceTest < ActiveSupport::TestCase
    setup do
      # Create users for testing guardian relationships with disabilities selected
      @guardian = create(:user,
                         first_name: 'Guardian',
                         last_name: 'User',
                         email: 'guardian_user@example.com',
                         hearing_disability: true)

      @dependent = create(:user,
                          first_name: 'Dependent',
                          last_name: 'User',
                          email: 'dependent_user@example.com',
                          vision_disability: true)

      # Create the guardian relationship
      @guardian_relationship = create(:guardian_relationship,
                                      guardian_user: @guardian,
                                      dependent_user: @dependent,
                                      relationship_type: 'Parent')

      # Create another user for the completed application
      @completed_app_user = create(:user,
                                   first_name: 'Completed',
                                   last_name: 'User',
                                   email: 'completed_user@example.com',
                                   mobility_disability: true)

      # And another for the draft app
      @draft_app_user = create(:user,
                               first_name: 'Draft',
                               last_name: 'User',
                               email: 'draft_user@example.com',
                               cognition_disability: true)

      # Use factories to create applications with disabilities
      @active_app = create(:application, status: :in_progress, income_proof_status: :not_reviewed, user: @dependent)
      @approved_app = create(:application, :completed, user: @completed_app_user) # :completed trait sets status and proofs to approved
      @draft_app = create(:application, status: :draft, user: @draft_app_user)

      # Create applications with managing_guardian for dependent applications testing
      @dependent_app = create(:application, status: :in_progress, user: @dependent, managing_guardian: @guardian)

      @scope = Application.all # Scope includes factory-created records

      # This setup might still be needed depending on what it does beyond basic attachment mocking
      setup_attachment_mocks_for_audit_logs
    end

    test 'applies no filters when params are empty' do
      with_mocked_attachments do
        service = FilterService.new(@scope)
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data
        assert_equal @scope.count, result_data.count
      end
    end

    test 'filters by application status' do
      with_mocked_attachments do
        service = FilterService.new(@scope, { filter: 'in_progress' })
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data
        assert_includes result_data, @active_app
        assert_not_includes result_data, @approved_app
        assert_not_includes result_data, @draft_app
      end
    end

    test 'filters by approved status' do
      with_mocked_attachments do
        service = FilterService.new(@scope, { filter: 'approved' })
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data
        assert_includes result_data, @approved_app
        assert_not_includes result_data, @active_app
        assert_not_includes result_data, @draft_app
      end
    end

    test 'filters by proofs needing review' do
      with_mocked_attachments do
        service = FilterService.new(@scope, { filter: 'proofs_needing_review' })
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data
        assert_includes result_data, @active_app
        assert_not_includes result_data, @approved_app
      end
    end

    # This test demonstrates the standardized approach to attachment mocking
    test 'filters by medical certifications to review' do
      # Set up applications with different statuses
      @active_app.update!(medical_certification_status: :received, status: :in_progress)
      @approved_app.update!(medical_certification_status: :approved, status: :approved) # Corrected enum value

      # Create a user for the rejected application
      @rejected_app_user = create(:user,
                                  first_name: 'Rejected',
                                  last_name: 'User',
                                  email: 'rejected_user@example.com',
                                  speech_disability: true)

      # Setup the rejected application with proper stubs for validation
      with_mocked_attachments do
        # Create a rejected application with received medical certification using factory
        # This should NOT appear in the results
        @rejected_app = create(:application,
                               user: @rejected_app_user,
                               status: :rejected,
                               income_proof_status: :approved, # Set proof statuses to pass validation
                               residency_proof_status: :approved)

        # Mock both income and residency proof attachments for validation
        income_proof_mock = mock_attached_file(
          filename: 'income_proof.pdf',
          content_type: 'application/pdf',
          created_at: 1.day.ago
        )
        residency_proof_mock = mock_attached_file(
          filename: 'residency_proof.pdf',
          content_type: 'application/pdf',
          created_at: 1.day.ago
        )
        @rejected_app.stubs(:income_proof).returns(income_proof_mock)
        @rejected_app.stubs(:income_proof_attached?).returns(true)
        @rejected_app.stubs(:residency_proof).returns(residency_proof_mock)
        @rejected_app.stubs(:residency_proof_attached?).returns(true)

        # Mock the medical certification as well
        medical_cert_mock = mock_attached_file(
          filename: 'medical_certification.pdf',
          content_type: 'application/pdf',
          created_at: 1.day.ago
        )
        @rejected_app.stubs(:medical_certification).returns(medical_cert_mock)
        @rejected_app.stubs(:medical_certification_attached?).returns(true)
        @rejected_app.update!(medical_certification_status: :received)

        service = FilterService.new(@scope, { filter: 'medical_certs_to_review' })
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data
        assert_includes result_data, @active_app
        assert_not_includes result_data, @approved_app
        assert_not_includes result_data, @rejected_app, 'Rejected applications should be excluded even with received medical certification'
      end
    end

    test 'filters by explicit status parameter' do
      with_mocked_attachments do
        service = FilterService.new(@scope, { status: 'draft' })
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data
        assert_includes result_data, @draft_app
        assert_not_includes result_data, @active_app
        assert_not_includes result_data, @approved_app
      end
    end

    test 'filters by date range' do
      with_mocked_attachments do
        # Set up applications with different dates
        @active_app.update!(created_at: Date.current)
        @approved_app.update!(created_at: 60.days.ago)
        @draft_app.update!(created_at: 100.days.ago)

        service = FilterService.new(@scope, { date_range: 'last_30' })
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data
        assert_includes result_data, @active_app
        assert_not_includes result_data, @approved_app
        assert_not_includes result_data, @draft_app
      end
    end

    test 'filters by search term' do
      with_mocked_attachments do
        # Create users with factories and set disabilities to pass validation
        user1 = create(:constituent,
                       first_name: 'John',
                       last_name: 'Smith',
                       email: 'john.smyth@example.com',
                       vision_disability: true)

        user2 = create(:constituent,
                       first_name: 'Janey',
                       last_name: 'Doe',
                       email: 'janey.doe@example.com',
                       hearing_disability: true)

        # Associate users with applications created in setup
        @active_app.update!(user: user1)
        @approved_app.update!(user: user2)

        service = FilterService.new(@scope, { q: 'Smith' })
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data
        assert_includes result_data, @active_app
        assert_not_includes result_data, @approved_app
      end
    end

    test 'combines multiple filter parameters' do
      with_mocked_attachments do
        # Set up applications with different properties
        # Ensure correct enum value is used if overriding factory default
        @active_app.update!(status: :in_progress, created_at: Date.current, income_proof_status: :not_reviewed)
        @approved_app.update!(status: :approved, created_at: 60.days.ago) # :completed trait already sets status: :approved

        # Filter by status and date range
        service = FilterService.new(@scope, { filter: 'in_progress', date_range: 'last_30' })
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data
        assert_includes result_data, @active_app
        assert_not_includes result_data, @approved_app
      end
    end

    test 'filters by managing guardian' do
      with_mocked_attachments do
        service = FilterService.new(@scope, { managing_guardian_id: @guardian.id })
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data
        assert_includes result_data, @dependent_app
        assert_not_includes result_data, @active_app
        assert_not_includes result_data, @approved_app
      end
    end

    test 'filters by applications for dependents of guardian' do
      with_mocked_attachments do
        # The @active_app and @dependent_app should both be for the @dependent user
        # And the @dependent user should have a guardian relationship with @guardian

        # Make sure the @active_app is also linked to the dependent
        @active_app.update!(user: @dependent)

        # Verify the guardian relationship exists
        assert @guardian.dependents.include?(@dependent),
               "Guardian relationship not established - guardian #{@guardian.id} should have dependent #{@dependent.id}"

        # Call the filter service with guardian_id parameter
        service = FilterService.new(@scope, { guardian_id: @guardian.id })
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data

        # Debug output
        puts "Guardian ID: #{@guardian.id}"
        puts "Dependent ID: #{@dependent.id}"
        puts "Found guardian relationships: #{GuardianRelationship.where(guardian_id: @guardian.id).count}"
        puts "Active app ID: #{@active_app.id}, user_id: #{@active_app.user_id}"
        puts "Dependent app ID: #{@dependent_app.id}, user_id: #{@dependent_app.user_id}"

        # Both applications with the dependent user should be included since they're for dependents of this guardian
        assert_includes result_data, @active_app
        assert_includes result_data, @dependent_app
        assert_not_includes result_data, @approved_app
      end
    end

    test 'filters by dependent applications only' do
      with_mocked_attachments do
        service = FilterService.new(@scope, { only_dependent_apps: 'true' })
        service_result = service.apply_filters

        assert service_result.success?, 'Expected service call to be successful'
        result_data = service_result.data
        assert_includes result_data, @dependent_app
        assert_not_includes result_data, @active_app
        assert_not_includes result_data, @approved_app
      end
    end

    test 'handles errors gracefully' do
      with_mocked_attachments do
        # Create a service with a scope that will raise an error when queried
        bad_scope = Object.new
        def bad_scope.where(*_args)
          raise StandardError, 'Test error'
        end

        # Use a parameter that triggers .where directly on the scope
        service = FilterService.new(bad_scope, { status: 'draft' })

        # It should return a failure result with the original scope in the data field
        service_result = service.apply_filters

        assert service_result.failure?, 'Expected service call to fail'
        assert_equal bad_scope, service_result.data, 'Expected data to be the original scope on failure'
        assert_equal 'Error applying filters: Test error', service_result.message
      end
    end
  end
end
