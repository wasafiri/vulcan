# frozen_string_literal: true

require 'test_helper'

module ConstituentPortal
  class GuardianApplicationsTest < ActionDispatch::IntegrationTest
    include ActionDispatch::TestProcess::FixtureFile

    setup do
      @user = users(:constituent_john)
      @valid_pdf = fixture_file_upload('test/fixtures/files/income_proof.pdf', 'application/pdf')
      @valid_image = fixture_file_upload('test/fixtures/files/residency_proof.pdf', 'application/pdf')

      sign_in(@user)
    end

    test 'should create application with guardian information' do
      assert_difference('Application.count') do
        assert_difference('Event.count') do
          post constituent_portal_applications_path, params: {
            application: {
              maryland_resident: true,
              household_size: 3,
              annual_income: 50_000,
              self_certify_disability: true,
              hearing_disability: true,
              is_guardian: '1',
              guardian_relationship: 'Parent'
            },
            medical_provider: {
              name: 'Dr. Smith',
              phone: '2025551234',
              email: 'drsmith@example.com'
            },
            submit_application: 'Submit Application'
          }
        end
      end

      application = Application.last
      assert_redirected_to constituent_portal_application_path(application)

      # Verify application was created successfully
      assert_equal 'in_progress', application.status

      # Verify user was updated with guardian information
      @user.reload
      assert @user.is_guardian
      assert_equal 'Parent', @user.guardian_relationship

      # Verify event was created
      event = Event.last
      assert_equal 'guardian_application_submitted', event.action
      assert_equal @user.id, event.user_id
      assert_equal application.id, event.metadata['application_id']
      assert_equal 'Parent', event.metadata['guardian_relationship']
    end

    test 'should update application with guardian information' do
      # Create a draft application first
      post constituent_portal_applications_path, params: {
        application: {
          maryland_resident: true,
          household_size: 3,
          annual_income: 50_000,
          self_certify_disability: true,
          hearing_disability: true
        },
        medical_provider: {
          name: 'Dr. Smith',
          phone: '2025551234',
          email: 'drsmith@example.com'
        },
        save_draft: 'Save Application'
      }

      application = Application.last

      # Now update it with guardian information
      assert_difference('Event.count') do
        patch constituent_portal_application_path(application), params: {
          application: {
            household_size: 4,
            annual_income: 60_000,
            is_guardian: '1',
            guardian_relationship: 'Legal Guardian'
          }
        }
      end

      # Verify application was updated successfully
      assert_redirected_to constituent_portal_application_path(application)
      application.reload
      assert_equal 4, application.household_size
      assert_equal 60_000, application.annual_income

      # Verify user was updated with guardian information
      @user.reload
      assert @user.is_guardian
      assert_equal 'Legal Guardian', @user.guardian_relationship

      # Verify event was created
      event = Event.last
      assert_equal 'guardian_application_updated', event.action
      assert_equal @user.id, event.user_id
      assert_equal application.id, event.metadata['application_id']
      assert_equal 'Legal Guardian', event.metadata['guardian_relationship']
    end
  end
end
