# frozen_string_literal: true

require 'test_helper'

class TestControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create(:admin) # Or any user type appropriate for testing this endpoint
  end

  test 'auth_status should return unauthenticated when not signed in' do
    get test_auth_status_url
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal false, json_response['authenticated']
    assert_nil json_response['email']
  end

  test 'auth_status should return authenticated when signed in' do
    sign_in @admin
    get test_auth_status_url
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal true, json_response['authenticated']
    assert_equal @admin.email, json_response['email']
    assert_equal @admin.id, json_response['user_id']
  end
end
