# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ProfileChangeAuditTest < ApplicationSystemTestCase
    setup do
      # Create admin with unique email to avoid conflicts
      @admin = FactoryBot.create(:admin, email: "profile_audit_admin_#{Time.now.to_i}_#{rand(10_000)}@example.com")
      @constituent = FactoryBot.create(:constituent, email: "profile_test_#{Time.now.to_i}_#{rand(10_000)}@example.com")
      @application = FactoryBot.create(:application, :old_enough_for_new_application, user: @constituent)

      # Clean up any profile change events created during user/application setup
      Event.where(action: %w[profile_updated profile_updated_by_guardian profile_created_by_admin_via_paper]).delete_all

      # Sign in with explicit wait handling to prevent timeouts
      system_test_sign_in(@admin)
      wait_for_turbo
    end

    test 'admin can see user profile changes in application audit log' do
      # First, simulate a user profile update by creating the event directly
      Event.create!(
        user: @constituent,
        action: 'profile_updated',
        metadata: {
          user_id: @constituent.id,
          changes: {
            'first_name' => { 'old' => 'Original Name', 'new' => 'Updated Name' },
            'email' => { 'old' => 'original@example.com', 'new' => 'updated@example.com' },
            'phone' => { 'old' => '555-123-4567', 'new' => '555-987-6543' }
          },
          updated_by: @constituent.id,
          timestamp: Time.current.iso8601
        },
        created_at: 1.hour.ago
      )

      visit admin_application_path(@application)
      
      # Wait for page to be fully loaded
      wait_for_turbo
      wait_for_network_idle(timeout: 10) if respond_to?(:wait_for_network_idle)

      within '#audit-logs' do
        assert_text 'Profile Updated', wait: 10
        assert_text "#{@constituent.full_name} updated their profile", wait: 5
        assert_text 'Email, Phone, First name', wait: 5
      end
      
      # Clear any pending network connections to prevent timeout during teardown
      clear_pending_network_connections if respond_to?(:clear_pending_network_connections)
    end

    test 'admin can see guardian profile changes for dependent applications' do
      # Create guardian and dependent with unique emails
      guardian = FactoryBot.create(:constituent, email: "guardian_test_#{Time.now.to_i}_#{rand(10_000)}@example.com")
      dependent = FactoryBot.create(:constituent, email: "dependent_test_#{Time.now.to_i}_#{rand(10_000)}@example.com")

      # Clean up profile events from creating these users
      Event.where(action: %w[profile_updated profile_updated_by_guardian profile_created_by_admin_via_paper]).delete_all

      # Create the guardian relationship properly
      GuardianRelationship.create!(
        guardian_id: guardian.id,
        dependent_id: dependent.id,
        relationship_type: 'Parent'
      )

      dependent_application = FactoryBot.create(:application, :old_enough_for_new_application, user: dependent, managing_guardian: guardian)

      # Create guardian updating dependent's profile
      Event.create!(
        user: guardian,
        action: 'profile_updated_by_guardian',
        metadata: {
          user_id: dependent.id,
          changes: {
            'first_name' => { 'old' => 'Child Name', 'new' => 'Updated Child Name' },
            'physical_address_1' => { 'old' => '123 Old St', 'new' => '456 New Ave' }
          },
          updated_by: guardian.id,
          timestamp: Time.current.iso8601
        },
        created_at: 30.minutes.ago
      )

      visit admin_application_path(dependent_application)
      
      # Wait for page to be fully loaded
      wait_for_turbo
      wait_for_network_idle(timeout: 10) if respond_to?(:wait_for_network_idle)

      within '#audit-logs' do
        assert_text 'Profile Updated', wait: 10
        assert_text "#{guardian.full_name} updated #{dependent.full_name}'s profile", wait: 5
        assert_text 'First name, Physical address 1', wait: 5
      end
      
      # Clear any pending network connections to prevent timeout during teardown
      clear_pending_network_connections if respond_to?(:clear_pending_network_connections)
    end

    test 'profile changes are chronologically ordered with other audit events' do
      # Clean up any existing profile events
      Event.where(action: %w[profile_updated profile_updated_by_guardian profile_created_by_admin_via_paper]).delete_all

      # Create multiple events at different times
      ApplicationStatusChange.create!(
        application: @application,
        user: @admin,
        from_status: 'draft',
        to_status: 'in_progress',
        created_at: 3.hours.ago
      )

      Event.create!(
        user: @constituent,
        action: 'profile_updated',
        metadata: {
          user_id: @constituent.id,
          changes: {
            'email' => { 'old' => 'old@example.com', 'new' => 'new@example.com' }
          },
          updated_by: @constituent.id,
          timestamp: Time.current.iso8601
        },
        created_at: 2.hours.ago
      )

      proof_review = ProofReview.create!(
        application: @application,
        admin: @admin,
        proof_type: 'income',
        status: 'rejected',
        rejection_reason: 'Test rejection for chronological ordering',
        reviewed_at: 1.hour.ago,
        created_at: 1.hour.ago
      )
      
      # Verify the ProofReview was created successfully
      assert proof_review.persisted?, "ProofReview should be persisted"
      assert_equal @application.id, proof_review.application_id

      # Clean up any notifications that might have been created
      Notification.where(notifiable: @application).delete_all

      visit admin_application_path(@application)
      
      # Wait for page to be fully loaded
      wait_for_turbo
      wait_for_network_idle(timeout: 10) if respond_to?(:wait_for_network_idle)

      # Wait for the page to fully load with stable waiting assertion
      assert_selector '#audit-logs tbody tr', minimum: 1, wait: 15

      within '#audit-logs' do
        # Wait for rows to appear
        assert_selector 'tbody tr', minimum: 4, wait: 15
        
        # Verify all expected content appears in audit logs
        assert_text 'Admin Review', wait: 10
        assert_text 'Profile Updated', wait: 5  
        assert_text 'Status Change', wait: 5
        assert_text 'Application Created', wait: 5

        # Verify chronological order by finding all rows and checking them
        rows = all('tbody tr')
        assert rows.count >= 4, "Expected at least 4 audit log entries, found #{rows.count}"
        
        # Check chronological order:
        # Row 0: Application Created (most recent - @application.created_at which is "now")
        # Row 1: Admin Review (1 hour ago)
        # Row 2: Profile Updated (2 hours ago) 
        # Row 3: Status Change (3 hours ago)
        assert rows[0].has_text?('Application Created'), "First row should contain 'Application Created'"
        assert rows[1].has_text?('Admin Review'), "Second row should contain 'Admin Review'"
        assert rows[2].has_text?('Profile Updated'), "Third row should contain 'Profile Updated'"
        assert rows[3].has_text?('Status Change'), "Fourth row should contain 'Status Change'"
      end
      
      # Clear any pending network connections to prevent timeout during teardown
      clear_pending_network_connections if respond_to?(:clear_pending_network_connections)
    end

    test 'profile changes show detailed field changes' do
      # Clean up any existing profile events
      Event.where(action: %w[profile_updated profile_updated_by_guardian profile_created_by_admin_via_paper]).delete_all

      Event.create!(
        user: @constituent,
        action: 'profile_updated',
        metadata: {
          user_id: @constituent.id,
          changes: {
            'first_name' => { 'old' => 'John', 'new' => 'Jonathan' },
            'last_name' => { 'old' => 'Doe', 'new' => 'Smith' },
            'email' => { 'old' => 'john.doe@example.com', 'new' => 'jonathan.smith@example.com' },
            'phone' => { 'old' => '555-123-4567', 'new' => '555-987-6543' },
            'physical_address_1' => { 'old' => '123 Main St', 'new' => '456 Oak Ave' },
            'city' => { 'old' => 'Baltimore', 'new' => 'Annapolis' },
            'state' => { 'old' => 'MD', 'new' => 'MD' },
            'zip_code' => { 'old' => '21201', 'new' => '21401' }
          },
          updated_by: @constituent.id,
          timestamp: Time.current.iso8601
        }
      )

      visit admin_application_path(@application)
      
      # Wait for page to be fully loaded
      wait_for_turbo
      wait_for_network_idle(timeout: 10) if respond_to?(:wait_for_network_idle)

      within '#audit-logs' do
        assert_text 'Profile Updated', wait: 10
        assert_text "#{@constituent.full_name} updated their profile", wait: 5

        detail_text = find('td', text: /updated their profile/, wait: 10).text
        assert_match(/City.*Email.*Phone.*State.*Zip code.*Last name.*First name.*Physical address 1/, detail_text)
      end
      
      # Clear any pending network connections to prevent timeout during teardown
      clear_pending_network_connections if respond_to?(:clear_pending_network_connections)
    end

    test 'no profile changes shown when none exist' do
      # Ensure no profile change events exist by cleaning up any that were created during setup
      Event.where(action: %w[profile_updated profile_updated_by_guardian profile_created_by_admin_via_paper]).delete_all

      visit admin_application_path(@application)
      
      # Wait for page to be fully loaded
      wait_for_turbo
      wait_for_network_idle(timeout: 10) if respond_to?(:wait_for_network_idle)

      within '#audit-logs' do
        assert_no_text 'Profile Updated'
        assert_no_text 'updated their profile'
        assert_no_text 'updated.*profile'
      end
      
      # Clear any pending network connections to prevent timeout during teardown
      clear_pending_network_connections if respond_to?(:clear_pending_network_connections)
    end
  end
end
