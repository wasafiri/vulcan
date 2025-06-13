# frozen_string_literal: true

require 'test_helper'

class GuardianApplicationFlowTest < ActionDispatch::IntegrationTest
  setup do
    # Setup a verified guardian user
    @guardian = create(:constituent, email: 'guardian@example.com', verified: true, email_verified: true)

    # Use post with credentials to sign in
    post sign_in_path, params: {
      email: @guardian.email,
      password: 'password123' # This should match what your factory creates
    }

    # Since in test environment sign_in doesn't redirect but just creates the session,
    # we expect 204 No Content and then manually navigate to dashboard
    assert_response :no_content

    # Now directly GET the dashboard (don't expect a redirect)
    get constituent_portal_dashboard_path
    assert_response :success
  end

  test 'guardian can access dashboard' do
    # Visit dashboard page
    get constituent_portal_dashboard_path
    assert_response :success
    assert_select 'h1', /Dashboard/
  end

  test 'guardian can create dependent' do
    # Get the new dependent form
    get new_constituent_portal_dependent_path
    assert_response :success

    # Submit the form with valid parameters including unique phone
    unique_phone = "555-#{rand(100..999)}-#{rand(1000..9999)}"
    assert_difference -> { @guardian.dependents.count } do
      post constituent_portal_dependents_path, params: {
        dependent: {
          first_name: 'Dependent',
          last_name: 'Child',
          email: 'dependent_child@example.com',
          phone: unique_phone,
          date_of_birth: 10.years.ago.to_date,
          vision_disability: true
        },
        guardian_relationship: {
          relationship_type: 'Parent'
        }
      }
    end

    # Verify redirect to dashboard
    assert_redirected_to constituent_portal_dashboard_path
  end

  test 'guardian can apply on behalf of a minor or dependent' do
    # ----- Arrange: create a dependent and the relationship -----
    unique_phone = "555-#{rand(100..999)}-#{rand(1000..9999)}"
    dependent = create(
      :constituent,
      first_name: 'Dependent',
      last_name: 'Child',
      email: 'dependent_child@example.com',
      phone: unique_phone,
      date_of_birth: 10.years.ago.to_date
    )

    GuardianRelationship.create!(
      guardian_user: @guardian,
      dependent_user: dependent,
      relationship_type: 'Parent'
    )

    # ----- Act: navigate through the UI flow -----
    # Visit dashboard to start
    get constituent_portal_dashboard_path
    assert_response :success

    # Verify dashboard has the button/link for dependent application
    # The view shows specific links for each dependent, not a generic "Apply for a Dependent" link
    assert_select 'a[href=?]', new_constituent_portal_application_path(user_id: dependent.id, for_self: false), text: "Apply for #{dependent.full_name}"

    # Navigate to the new application form for the dependent
    get new_constituent_portal_application_path(for_self: false)
    assert_response :success

    # Verify the form has a section for selecting the dependent
    assert_select "select[name='application[user_id]']"

    # ----- Submit the form with all required parameters -----
    assert_difference -> { Application.count } do
      post constituent_portal_applications_path, params: {
        application: {
          user_id: dependent.id, # This is how the form identifies the dependent
          maryland_resident: true,
          household_size: 4,
          annual_income: 50_000,
          self_certify_disability: true,
          vision_disability: true,
          medical_provider_name: 'Dr. Test',
          medical_provider_phone: '123-456-7890',
          medical_provider_email: 'doctor@example.com',
          submit_application: true # Simulate clicking the Submit Application button
        }
      }
    end

    # Verify redirection after submission
    assert_redirected_to constituent_portal_application_path(Application.last)

    # ----- Assert: the application was created with correct attributes -----
    application = Application.last
    assert_equal dependent.id, application.user_id, 'Application should belong to the dependent'
    assert_equal @guardian.id, application.managing_guardian_id, 'Guardian should be set as the managing guardian'
    # application.vision_disability is not a direct column - check self_certify_disability instead
    assert application.self_certify_disability, 'Disability should be self-certified'
    assert_equal 4, application.household_size, 'Household size should be set correctly'
    assert_equal 50_000, application.annual_income, 'Annual income should be set correctly'
  end

  test 'dependent applications appear on guardian dashboard' do
    # Create a dependent
    unique_phone = "555-#{rand(100..999)}-#{rand(1000..9999)}"
    dependent = create(:constituent, first_name: 'Dependent', last_name: 'Child', phone: unique_phone)

    # Create the guardian relationship
    GuardianRelationship.create!(
      guardian_user: @guardian,
      dependent_user: dependent,
      relationship_type: 'Parent'
    )

    # Create an application for the dependent managed by the guardian
    application = create(:application,
                         user: dependent,
                         managing_guardian: @guardian,
                         status: 'in_progress')

    # Visit the dashboard
    get constituent_portal_dashboard_path
    assert_response :success

    # Verify the dependent's application appears
    assert_select 'a[href=?]', constituent_portal_application_path(application)
    assert_select 'td', text: dependent.full_name
  end
end
