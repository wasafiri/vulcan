# frozen_string_literal: true

require 'test_helper'

module ConstituentPortal
  class ApplicationsControllerAutosaveTest < ActionDispatch::IntegrationTest
    setup do
      # Set up test data using factories
      @user = create(:constituent, :with_disabilities)
      @draft_application = create(:application, user: @user, status: :draft)

      # Sign in the user for all tests
      sign_in(@user)

      # Set thread local context to skip proof validations in tests
      Thread.current[:paper_application_context] = true
    end

    teardown do
      # Clean up thread local context after each test
      Thread.current[:paper_application_context] = nil
    end

    #------------------------------------------
    # Tests for autosaving Application fields
    #------------------------------------------

    test 'should autosave Application field for existing draft' do
      # Test autosaving household_size for an existing application
      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: 'application[household_size]', field_value: '4' },
            as: :json

      # Verify the response
      assert_response :success
      assert_json_response(success: true)

      # Verify the application was updated
      @draft_application.reload
      assert_equal 4, @draft_application.household_size
    end

    test 'should autosave Application field for new draft' do
      # Test autosaving for a new application (no ID provided)
      assert_difference('Application.count') do
        patch autosave_field_constituent_portal_applications_path,
              params: { field_name: 'application[household_size]', field_value: '3' },
              as: :json
      end

      # Verify the response
      assert_response :success
      response_data = response.parsed_body
      assert response_data['success']
      assert_not_nil response_data['applicationId']

      # Verify the application was created with correct values
      new_application = Application.find(response_data['applicationId'])
      assert_equal 3, new_application.household_size
      assert_equal 'draft', new_application.status
      assert_equal @user.id, new_application.user_id
    end

    test 'should not autosave invalid Application field' do
      # Test autosaving an invalid annual_income
      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: 'application[annual_income]', field_value: 'invalid' },
            as: :json

      # Verify the response indicates error
      assert_response :unprocessable_entity
      response_data = response.parsed_body
      assert_not response_data['success']
      assert response_data['errors'].present?

      # Verify the application was not updated
      original_income = @draft_application.annual_income
      @draft_application.reload
      assert_equal original_income, @draft_application.annual_income
    end

    test 'should autosave boolean Application field' do
      # Test autosaving self_certify_disability
      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: 'application[self_certify_disability]', field_value: 'true' },
            as: :json

      # Verify the response
      assert_response :success
      assert_json_response(success: true)

      # Verify the boolean was correctly cast and saved
      @draft_application.reload
      assert_equal true, @draft_application.self_certify_disability
    end

    test 'should autosave medical provider fields' do
      # Test autosaving nested medical provider field
      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: 'application[medical_provider_attributes][name]', field_value: 'Dr. Jane Smith' },
            as: :json

      # Verify the response
      assert_response :success
      assert_json_response(success: true)

      # Verify the application was updated
      @draft_application.reload
      assert_equal 'Dr. Jane Smith', @draft_application.medical_provider_name
    end

    test 'should update last_visited_step when autosaving Application field' do
      field_name = 'application[household_size]'
      attribute_name = 'household_size' # The actual attribute name

      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: field_name, field_value: '5' },
            as: :json

      assert_response :success
      @draft_application.reload
      assert_equal attribute_name, @draft_application.last_visited_step
    end

    #------------------------------------------
    # Tests for autosaving User fields
    #------------------------------------------

    test 'should autosave User disability field' do
      # Test autosaving hearing_disability
      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: 'application[hearing_disability]', field_value: 'true' },
            as: :json

      # Verify the response
      assert_response :success
      assert_json_response(success: true)

      # Verify the user was updated
      @user.reload
      assert_equal true, @user.hearing_disability
    end

    test 'should autosave guardian status' do
      # Test updating is_guardian
      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: 'application[is_guardian]', field_value: 'true' },
            as: :json

      # Verify the response
      assert_response :success
      assert_json_response(success: true)

      # Verify the user was updated
      @user.reload
      assert_equal true, @user.is_guardian
    end

    test 'should autosave guardian relationship' do
      # First set is_guardian to true
      @user.update(is_guardian: true)

      # Test updating guardian_relationship
      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: 'application[guardian_relationship]', field_value: 'Parent' },
            as: :json

      # Verify the response
      assert_response :success
      assert_json_response(success: true)

      # Verify the user was updated
      @user.reload
      assert_equal 'Parent', @user.guardian_relationship
    end

    test 'should update last_visited_step when autosaving User field' do
      field_name = 'application[hearing_disability]'
      attribute_name = 'hearing_disability' # The actual attribute name

      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: field_name, field_value: 'false' },
            as: :json

      assert_response :success
      @draft_application.reload
      assert_equal attribute_name, @draft_application.last_visited_step
    end

    test 'should not autosave empty guardian relationship when is_guardian is true' do
      # Set up our test state with update_columns to skip validations
      @user.update_columns(
        guardian_relationship: 'Parent',
        is_guardian: true
      )

      # Make sure current_user in the controller matches our test user
      sign_in(@user)

      # Make the request - try to set guardian_relationship to empty
      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: 'application[guardian_relationship]', field_value: '' },
            as: :json

      # Verify the response indicates error
      assert_response :unprocessable_entity
      response_data = response.parsed_body
      assert_not response_data['success']
      assert response_data['errors'].present?
      assert_includes response_data['errors']['application[guardian_relationship]'].first, "can't be blank"

      # Verify the user was not updated
      @user.reload
      assert_equal 'Parent', @user.guardian_relationship
    end

    #------------------------------------------
    # Tests for ignoring certain fields
    #------------------------------------------

    test 'should not autosave file upload fields' do
      # Test autosaving a file field
      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: 'application[income_proof]', field_value: 'some_file.pdf' },
            as: :json

      # Verify the response indicates error
      assert_response :unprocessable_entity
      response_data = response.parsed_body
      assert_not response_data['success']
      assert response_data['errors'].present?
    end

    test 'should return error for non-autosavable address fields' do
      # Store original address value
      original_address = @user.physical_address_1

      # Test autosaving a physical address field
      patch autosave_field_constituent_portal_application_path(@draft_application),
            params: { field_name: 'application[physical_address_1]', field_value: '123 Main St Ignored' },
            as: :json

      # Verify the response indicates error
      assert_response :unprocessable_entity
      response_data = response.parsed_body
      assert_not response_data['success']
      assert response_data['errors'].present?
      assert_includes response_data['errors']['application[physical_address_1]'].first, 'cannot be autosaved'

      # Verify the user's address was NOT updated
      @user.reload
      assert_equal original_address, @user.physical_address_1
    end

    #------------------------------------------
    # Helper methods
    #------------------------------------------

    def assert_json_response(expected)
      response_data = response.parsed_body
      expected.each do |key, value|
        assert_equal value, response_data[key.to_s], "Expected response to have #{key}=#{value}"
      end
    end
  end
end
