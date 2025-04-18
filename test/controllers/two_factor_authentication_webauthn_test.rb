# frozen_string_literal: true

require 'test_helper'
require 'webauthn/fake_client'
require 'support/webauthn_test_helper'

# Integration tests for WebAuthn authentication flow
class TwoFactorAuthenticationWebauthnTest < ActionDispatch::IntegrationTest
  include WebauthnTestHelper
  include AuthenticationTestHelper

  setup do
    # Create a user with WebAuthn credentials and make sure it has proper auth setup 
    @user = users(:constituent_with_webauthn)
    @user.webauthn_credentials.destroy_all
    @user.update_column(:webauthn_id, WebAuthn.generate_user_id) 
    @credential = create(:webauthn_credential, user: @user)

    # We don't need to set second_factor_enabled, since having a webauthn credential 
    # enables that automatically via the second_factor_enabled? method in the User model

    # Setup WebAuthn test environment
    WebAuthn.configure do |config|
      config.allowed_origins = ['https://example.com']
    end

    # For debugging
    ENV['DEBUG_AUTH'] = 'true'
  end

  teardown do
    ENV['DEBUG_AUTH'] = nil
  end

  test 'should get new form for WebAuthn authentication after password step' do
    # Step 1: Sign in, expect redirect to 2FA verify page
    post sign_in_path, params: { email: @user.email, password: 'password123' }
    assert_response :redirect
    assert_redirected_to verify_method_two_factor_authentication_path(type: 'webauthn')

    # Step 2: Follow the redirect explicitly
    get verify_method_two_factor_authentication_path(type: 'webauthn')
    assert_response :success

    # Step 3: Now check the verification page content
    assert_select 'form' # Check that there's at least one form on the page
  end

  test 'should generate options for WebAuthn authentication' do
    # Step 1: Sign in, expect redirect to 2FA verify page
    post sign_in_path, params: { email: @user.email, password: 'password123' }
    assert_response :redirect
    assert_redirected_to verify_method_two_factor_authentication_path(type: 'webauthn')

    # Step 2: Follow the redirect explicitly to ensure session state is correct
    get verify_method_two_factor_authentication_path(type: 'webauthn')
    assert_response :success

    # Step 3: Now get the options JSON from the verification options path
    get verification_options_two_factor_authentication_path(type: 'webauthn'), xhr: true,
                                                                               headers: { 'X-Requested-With' => 'XMLHttpRequest' }
    assert_response :success

    # Parse the response and verify it includes required fields
    json_response = response.parsed_body
    assert json_response.key?('challenge')
    assert json_response.key?('allowCredentials')
  end

  test 'should correctly route WebAuthn credential verification requests' do
    # Step 1: Sign in, expect redirect to 2FA verify page
    post sign_in_path, params: { email: @user.email, password: 'password123' }
    assert_response :redirect
    assert_redirected_to verify_method_two_factor_authentication_path(type: 'webauthn')

    # Step 2: Follow the redirect explicitly
    get verify_method_two_factor_authentication_path(type: 'webauthn')
    assert_response :success

    # Step 3: Now test the verification processing endpoint
    # Create a proper credential mock with an id method
    mock_credential = Minitest::Mock.new
    mock_credential.expect :id, 'nonexistent-credential-id'

    # Mock the WebAuthn::Credential.from_get method
    WebAuthn::Credential.stub :from_get, mock_credential do
      post process_verification_two_factor_authentication_path(type: 'webauthn'),
           params: { credential: { id: 'test-credential-id' } },
           as: :json

      # We expect not_found response since our credential id doesn't exist
      assert_response :not_found
    end
  end

  test 'should reject if password step not completed' do
    # Try to access WebAuthn page without completing password step
    get verify_method_two_factor_authentication_path(type: 'webauthn')
    assert_redirected_to sign_in_path

    # Try to get options without completing password step
    get verification_options_two_factor_authentication_path(type: 'webauthn'), xhr: true
    assert_response :redirect
    assert_redirected_to sign_in_path
  end

  test 'should have proper error handling for malformed credentials' do
    # Step 1: Sign in, expect redirect to 2FA verify page
    post sign_in_path, params: { email: @user.email, password: 'password123' }
    assert_response :redirect
    assert_redirected_to verify_method_two_factor_authentication_path(type: 'webauthn')

    # Step 2: Follow the redirect explicitly
    get verify_method_two_factor_authentication_path(type: 'webauthn')
    assert_response :success

    # Step 3: Now test the verification processing endpoint with bad data
    # Create a proper credential mock with an id method
    mock_credential = Minitest::Mock.new
    mock_credential.expect :id, 'malformed-credential-id'

    # Mock the WebAuthn::Credential.from_get method to return our mock
    WebAuthn::Credential.stub :from_get, mock_credential do
      # Post invalid data to trigger error handling
      post process_verification_two_factor_authentication_path(type: 'webauthn'),
           params: { invalid: 'data' },
           as: :json

      # Verify we get an appropriate error response - not_found because the credential ID won't exist
      assert_response :not_found
    end
  end
end
