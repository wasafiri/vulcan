# frozen_string_literal: true

require 'test_helper'

module Applications
  class FilterServiceTest < ActiveSupport::TestCase
    setup do
      # Use factories instead of fixtures
      @active_app = create(:application, status: :in_progress, income_proof_status: :not_reviewed) # Base factory defaults work too
      @approved_app = create(:application, :completed) # :completed trait sets status and proofs to approved
      @draft_app = create(:application, status: :draft)
      @scope = Application.all # Scope includes factory-created records

      # This setup might still be needed depending on what it does beyond basic attachment mocking
      setup_attachment_mocks_for_audit_logs
    end

    test 'applies no filters when params are empty' do
      with_mocked_attachments do
        service = FilterService.new(@scope)
        result = service.apply_filters

        assert_equal @scope.count, result.count
      end
    end

    test 'filters by application status' do
      with_mocked_attachments do
        service = FilterService.new(@scope, { filter: 'in_progress' })
        result = service.apply_filters

        assert_includes result, @active_app
        assert_not_includes result, @approved_app
        assert_not_includes result, @draft_app
      end
    end

    test 'filters by approved status' do
      # assert_test_has_assertions # Removed due to NameError

      with_mocked_attachments do
        service = FilterService.new(@scope, { filter: 'approved' })
        result = service.apply_filters

        assert_includes result, @approved_app
        assert_not_includes result, @active_app
        assert_not_includes result, @draft_app
      end
    end

    test 'filters by proofs needing review' do
      # assert_test_has_assertions # Removed due to NameError

      with_mocked_attachments do
        service = FilterService.new(@scope, { filter: 'proofs_needing_review' })
        result = service.apply_filters

        assert_includes result, @active_app
        assert_not_includes result, @approved_app
      end
    end

    # This test demonstrates the standardized approach to attachment mocking
    test 'filters by medical certifications to review' do
      # assert_test_has_assertions # Removed due to NameError

      # Set up applications with different statuses
      @active_app.update!(medical_certification_status: :received, status: :in_progress)
      @approved_app.update!(medical_certification_status: :approved, status: :approved) # Corrected enum value

      # Create a rejected application with received medical certification using factory
      # This should NOT appear in the results
      @rejected_app = create(:application, :rejected) # Use the :rejected trait

      # Use the new standardized mocking approach directly
      # This provides clear control over the mock attachment with better maintainability
      medical_cert_mock = mock_attached_file(
        filename: 'medical_certification.pdf',
        content_type: 'application/pdf',
        created_at: 1.day.ago
      )
      @rejected_app.stubs(:medical_certification).returns(medical_cert_mock)
      @rejected_app.stubs(:medical_certification_attached?).returns(true)
      @rejected_app.update!(medical_certification_status: :received)

      service = FilterService.new(@scope, { filter: 'medical_certs_to_review' })
      result = service.apply_filters

      assert_includes result, @active_app
      assert_not_includes result, @approved_app
      assert_not_includes result, @rejected_app, 'Rejected applications should be excluded even with received medical certification'
    end

    test 'filters by explicit status parameter' do
      # assert_test_has_assertions # Removed due to NameError

      with_mocked_attachments do
        service = FilterService.new(@scope, { status: 'draft' })
        result = service.apply_filters

        assert_includes result, @draft_app
        assert_not_includes result, @active_app
        assert_not_includes result, @approved_app
      end
    end

    test 'filters by date range' do
      # assert_test_has_assertions # Removed due to NameError

      with_mocked_attachments do
        # Set up applications with different dates
        @active_app.update!(created_at: Date.current)
        @approved_app.update!(created_at: 60.days.ago)
        @draft_app.update!(created_at: 100.days.ago)

        service = FilterService.new(@scope, { date_range: 'last_30' })
        result = service.apply_filters

        assert_includes result, @active_app
        assert_not_includes result, @approved_app
        assert_not_includes result, @draft_app
      end
    end

    test 'filters by search term' do
      # assert_test_has_assertions # Removed due to NameError

      with_mocked_attachments do
        # Create users with factories
        user1 = create(:constituent, first_name: 'John', last_name: 'Smith')
        user2 = create(:constituent, first_name: 'Jane', last_name: 'Doe')

        # Associate users with applications created in setup
        @active_app.update!(user: user1)
        @approved_app.update!(user: user2)

        service = FilterService.new(@scope, { q: 'Smith' })
        result = service.apply_filters

        assert_includes result, @active_app
        assert_not_includes result, @approved_app
      end
    end

    test 'combines multiple filter parameters' do
      # assert_test_has_assertions # Removed due to NameError

      with_mocked_attachments do
        # Set up applications with different properties
        # Ensure correct enum value is used if overriding factory default
        @active_app.update!(status: :in_progress, created_at: Date.current, income_proof_status: :not_reviewed)
        @approved_app.update!(status: :approved, created_at: 60.days.ago) # :completed trait already sets status: :approved

        # Filter by status and date range
        service = FilterService.new(@scope, { filter: 'in_progress', date_range: 'last_30' })
        result = service.apply_filters

        assert_includes result, @active_app
        assert_not_includes result, @approved_app
      end
    end

    test 'handles errors gracefully' do
      # assert_test_has_assertions # Removed due to NameError

      with_mocked_attachments do
        # Create a service with a scope that will raise an error when queried
        bad_scope = Object.new
        def bad_scope.where(*_args)
          raise StandardError, 'Test error'
        end

        # Use a parameter that triggers .where directly on the scope
        service = FilterService.new(bad_scope, { status: 'draft' })

        # It should return the original scope and add an error
        result = service.apply_filters
        assert_equal bad_scope, result
        assert_includes service.errors, 'Error applying filters: Test error'
      end
    end
  end
end
