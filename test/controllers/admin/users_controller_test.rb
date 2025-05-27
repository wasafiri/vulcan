# frozen_string_literal: true

require 'test_helper'

module Admin
  class UsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      sign_in @admin
    end

    test 'should create new constituent user as guardian' do
      unique_email = "new.test.guardian.#{Time.now.to_i}@example.com"

      assert_difference('Users::Constituent.count') do
        post admin_users_path, params: {
          first_name: 'New',
          last_name: 'Guardian',
          email: unique_email,
          phone: '555-987-6543',
          physical_address_1: '123 Maple Street',
          city: 'Baltimore',
          state: 'MD',
          zip_code: '21201',
          communication_preference: 'email'
        }, as: :json
      end

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response['success']
      assert_equal 'New', json_response['user']['first_name']
      assert_equal 'Guardian', json_response['user']['last_name']

      # Verify user was created properly
      user = Users::Constituent.find_by(email: unique_email)
      assert user.present?
      assert user.force_password_change?
      assert user.verified?
    end

    test 'should handle validation errors' do
      assert_no_difference('Users::Constituent.count') do
        post admin_users_path, params: {
          # Missing required fields
          first_name: '',
          last_name: '',
          email: 'invalid-email'
        }, as: :json
      end

      assert_response :unprocessable_entity
      json_response = JSON.parse(response.body)
      assert_not json_response['success']
      assert json_response['errors'].present?
    end

    test 'should detect potential duplicate guardians' do
      existing_user = users(:constituent)

      assert_difference('Users::Constituent.count') do
        post admin_users_path, params: {
          first_name: existing_user.first_name,
          last_name: existing_user.last_name,
          date_of_birth: existing_user.date_of_birth,
          email: 'different.email@example.com',
          phone: '555-999-8888',
          physical_address_1: '123 Main St',
          city: 'Baltimore',
          state: 'MD',
          zip_code: '21202',
          communication_preference: 'email'
        }, as: :json
      end

      assert_response :success

      # Verify user was created with needs_duplicate_review flag
      user = Users::Constituent.find_by(email: 'different.email@example.com')
      assert user.present?
      assert user.needs_duplicate_review?
    end
  end
end
