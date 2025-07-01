# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ProfileChangeAuditTest < ApplicationSystemTestCase
    setup do
      @admin = create(:admin)
      @constituent = create(:constituent)
      @application = create(:application, user: @constituent)
      sign_in(@admin)
    end

    test 'admin can see user profile changes in application audit log' do
      # First, simulate a user profile update by creating the event directly
      # (In real usage, this would happen when user updates their profile)
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

      # Visit the application page
      visit admin_application_path(@application)

      # Verify the audit log shows the profile update
      within '#audit-logs' do
        assert_text 'Profile Updated'
        assert_text "#{@constituent.full_name} updated their profile"
        assert_text 'First name, Email, Phone'
      end
    end

    test 'admin can see guardian profile changes for dependent applications' do
      # Create guardian and dependent
      guardian = create(:constituent)
      dependent = create(:constituent)
      GuardianRelationship.create!(
        guardian_user: guardian,
        dependent_user: dependent,
        relationship_type: 'Parent'
      )
      dependent_application = create(:application, user: dependent, managing_guardian: guardian)

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

      # Visit the dependent's application page
      visit admin_application_path(dependent_application)

      # Verify the audit log shows the guardian update
      within '#audit-logs' do
        assert_text 'Profile Updated'
        assert_text "#{guardian.full_name} updated #{dependent.full_name}'s profile"
        assert_text 'First name, Physical address 1'
      end
    end

    test 'profile changes are chronologically ordered with other audit events' do
      # Create multiple events at different times

      # Application status change (oldest)
      ApplicationStatusChange.create!(
        application: @application,
        user: @admin,
        from_status: 'draft',
        to_status: 'in_progress',
        created_at: 3.hours.ago
      )

      # Profile update (middle)
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

      # Proof review (newest)
      ProofReview.create!(
        application: @application,
        admin: @admin,
        proof_type: 'income',
        status: 'approved',
        reviewed_at: 1.hour.ago,
        created_at: 1.hour.ago
      )

      # Visit the application page
      visit admin_application_path(@application)

      # Verify events are in chronological order (newest first)
      within '#audit-logs tbody' do
        rows = all('tr')

        # First row should be the proof review (newest)
        within rows[0] do
          assert_text 'Admin Review'
        end

        # Second row should be the profile update (middle)
        within rows[1] do
          assert_text 'Profile Updated'
        end

        # Third row should be the status change (oldest)
        within rows[2] do
          assert_text 'Status Change'
        end
      end
    end

    test 'profile changes show detailed field changes' do
      # Create a profile update with multiple field changes
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

      # Visit the application page
      visit admin_application_path(@application)

      # Verify the audit log shows all the changed fields
      within '#audit-logs' do
        assert_text 'Profile Updated'
        assert_text "#{@constituent.full_name} updated their profile"

        # Check that the summary includes the changed fields
        detail_text = find('td', text: /updated their profile/).text
        assert_match(/First name.*Last name.*Email.*Phone.*Physical address 1.*City.*Zip code/, detail_text)
      end
    end

    test 'no profile changes shown when none exist' do
      # Don't create any profile change events

      # Visit the application page
      visit admin_application_path(@application)

      # Verify no profile update entries exist
      within '#audit-logs' do
        assert_no_text 'Profile Updated'
        assert_no_text 'updated their profile'
        assert_no_text 'updated.*profile'
      end
    end
  end
end
