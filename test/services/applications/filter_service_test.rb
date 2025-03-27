# frozen_string_literal: true

require 'test_helper'

module Applications
  class FilterServiceTest < ActiveSupport::TestCase
    setup do
      @scope = Application.all
      @active_app = applications(:active)
      @approved_app = applications(:approved)
      @draft_app = applications(:draft)

      # Set up properly prepared applications for testing
      prepare_application_for_test(@active_app, status: 'in_progress', income_proof_status: 'not_reviewed')
      prepare_application_for_test(@approved_app, status: 'approved', residency_proof_status: 'approved')
      prepare_application_for_test(@draft_app, status: 'draft')
    end

    test 'applies no filters when params are empty' do
      service = FilterService.new(@scope)
      result = service.apply_filters

      assert_equal @scope.count, result.count
    end

    test 'filters by application status' do
      service = FilterService.new(@scope, { filter: 'in_progress' })
      result = service.apply_filters

      assert_includes result, @active_app
      assert_not_includes result, @approved_app
      assert_not_includes result, @draft_app
    end

    test 'filters by approved status' do
      service = FilterService.new(@scope, { filter: 'approved' })
      result = service.apply_filters

      assert_includes result, @approved_app
      assert_not_includes result, @active_app
      assert_not_includes result, @draft_app
    end

    test 'filters by proofs needing review' do
      service = FilterService.new(@scope, { filter: 'proofs_needing_review' })
      result = service.apply_filters

      assert_includes result, @active_app
      assert_not_includes result, @approved_app
    end

    test 'filters by medical certifications to review' do
      # Set up an application with medical certification status "received"
      @active_app.update!(medical_certification_status: :received)
      @approved_app.update!(medical_certification_status: :accepted)

      service = FilterService.new(@scope, { filter: 'medical_certs_to_review' })
      result = service.apply_filters

      assert_includes result, @active_app
      assert_not_includes result, @approved_app
    end

    test 'filters by explicit status parameter' do
      service = FilterService.new(@scope, { status: 'draft' })
      result = service.apply_filters

      assert_includes result, @draft_app
      assert_not_includes result, @active_app
      assert_not_includes result, @approved_app
    end

    test 'filters by date range' do
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

    test 'filters by search term' do
      # Make sure the applications have users with known names
      user1 = users(:confirmed_user)
      user2 = users(:unconfirmed_user)

      user1.update!(first_name: 'John', last_name: 'Smith')
      user2.update!(first_name: 'Jane', last_name: 'Doe')

      @active_app.update!(user: user1)
      @approved_app.update!(user: user2)

      service = FilterService.new(@scope, { q: 'Smith' })
      result = service.apply_filters

      assert_includes result, @active_app
      assert_not_includes result, @approved_app
    end

    test 'combines multiple filter parameters' do
      # Set up applications with different properties
      @active_app.update!(status: 'in_progress', created_at: Date.current, income_proof_status: 'not_reviewed')
      @approved_app.update!(status: 'approved', created_at: 60.days.ago)

      # Filter by status and date range
      service = FilterService.new(@scope, { filter: 'in_progress', date_range: 'last_30' })
      result = service.apply_filters

      assert_includes result, @active_app
      assert_not_includes result, @approved_app
    end

    test 'handles errors gracefully' do
      # Create a service with a scope that will raise an error when queried
      bad_scope = Object.new
      def bad_scope.where(*_args)
        raise StandardError, 'Test error'
      end

      service = FilterService.new(bad_scope, { filter: 'active' })

      # It should return the original scope and add an error
      result = service.apply_filters
      assert_equal bad_scope, result
      assert_includes service.errors, 'Error applying filters: Test error'
    end
  end
end
