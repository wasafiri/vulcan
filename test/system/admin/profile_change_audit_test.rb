# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ProfileChangeAuditTest < ApplicationSystemTestCase
    setup do
      @admin = FactoryBot.create(:admin)
      @constituent = FactoryBot.create(:constituent, email: "profile_test_#{Time.now.to_i}_#{rand(10_000)}@example.com")
      @application = FactoryBot.create(:application, :old_enough_for_new_application, user: @constituent)

      # Clean up any profile change events created during user/application setup
      Event.where(action: %w[profile_updated profile_updated_by_guardian profile_created_by_admin_via_paper]).delete_all

      sign_in(@admin)
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

      within '#audit-logs' do
        assert_text 'Profile Updated'
        assert_text "#{@constituent.full_name} updated their profile"
        assert_text 'Email, Phone, First name'
      end
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

      within '#audit-logs' do
        assert_text 'Profile Updated'
        assert_text "#{guardian.full_name} updated #{dependent.full_name}'s profile"
        assert_text 'First name, Physical address 1'
      end
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

      ProofReview.create!(
        application: @application,
        admin: @admin,
        proof_type: 'income',
        status: 'rejected',
        rejection_reason: 'Test rejection for chronological ordering',
        reviewed_at: 1.hour.ago,
        created_at: 1.hour.ago
      )

      # Clean up any notifications that might have been created
      Notification.where(notifiable: @application).delete_all

      visit admin_application_path(@application)

      within '#audit-logs tbody' do
        rows = all('tr')

        within rows[0] do
          assert_text 'Admin Review'
        end

        within rows[1] do
          assert_text 'Profile Updated'
        end

        within rows[2] do
          assert_text 'Status Change'
        end
      end
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

      within '#audit-logs' do
        assert_text 'Profile Updated'
        assert_text "#{@constituent.full_name} updated their profile"

        detail_text = find('td', text: /updated their profile/).text
        assert_match(/City.*Email.*Phone.*State.*Zip code.*Last name.*First name.*Physical address 1/, detail_text)
      end
    end

    test 'no profile changes shown when none exist' do
      # Ensure no profile change events exist by cleaning up any that were created during setup
      Event.where(action: %w[profile_updated profile_updated_by_guardian profile_created_by_admin_via_paper]).delete_all

      visit admin_application_path(@application)

      within '#audit-logs' do
        assert_no_text 'Profile Updated'
        assert_no_text 'updated their profile'
        assert_no_text 'updated.*profile'
      end
    end
  end
end
