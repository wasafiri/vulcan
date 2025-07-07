# frozen_string_literal: true

require 'webauthn/fake_client'

module WebauthnTestHelper
  # Helper to properly setup two-factor authentication session state in integration tests
  def setup_two_factor_session(user, type = :webauthn)
    # In integration tests, we need to POST to a route that sets up the session
    # First sign in to initiate the flow
    post sign_in_path, params: {
      email: user.email,
      password: 'password123'
    }

    # For integration tests, we need to manually setup the session data
    session[:pending_user_id] = user.id
    session[TwoFactorAuth::SESSION_KEYS[:type]] = type
    session[:two_factor_auth_in_progress] = user.id

    # Return true to indicate success
    true
  end

  def create_fake_credential(_user, client, options = {})
    # Get challenge using proper HTTP method call for integration tests
    return create_webauthn_credential_directly(_user, client, options) unless respond_to?(:get)

    # Integration test context - use HTTP methods
    get webauthn_creation_options_two_factor_authentication_path, xhr: true
    challenge = session[TwoFactorAuth::SESSION_KEYS[:challenge]]

    # System test context - we can't easily simulate the challenge request
    # For system tests, we'll skip the challenge part and create a credential directly

    # Generate fake credential using the challenge
    attestation_response = client.create(
      challenge: challenge,
      rp_id: URI.parse(client.origin).host,
      user_present: options[:user_present] || true,
      user_verified: options[:user_verified] || true
    )

    # Create a mock WebAuthn::Credential
    mock_credential = Minitest::Mock.new
    mock_credential.expect :id, attestation_response['id']
    mock_credential.expect :public_key, 'dummy_public_key_for_testing'
    mock_credential.expect :sign_count, 0

    # Create a WebauthnCredential record
    WebAuthn::Credential.stub :from_create, mock_credential do
      mock_credential.expect :verify, true, [String]

      return nil unless respond_to?(:post)

      post create_credential_two_factor_authentication_path(type: 'webauthn'), params: {
        id: attestation_response['id'],
        response: {
          attestationObject: attestation_response['response']['attestationObject'],
          clientDataJSON: attestation_response['response']['clientDataJSON']
        },
        credential_nickname: options[:nickname] || 'Test Security Key'
      }, as: :json

      # For system tests, we can't easily simulate this
    end

    # Return the created credential
    WebauthnCredential.find_by(nickname: options[:nickname] || 'Test Security Key')
  end

  # Helper method to create WebAuthn credential directly for system tests
  def create_webauthn_credential_directly(user, client, options = {})
    # Generate a fake credential response
    attestation_response = client.create(
      # WebAuthn challenges are base64-url strings without padding
      challenge: Base64.urlsafe_encode64(SecureRandom.random_bytes(32), padding: false),
      rp_id: URI.parse(client.origin).host,
      user_present: options[:user_present] || true,
      user_verified: options[:user_verified] || true
    )

    # Create the credential directly in the database
    user.webauthn_credentials.create!(
      # Use URL-safe Base64 (no padding) per WebAuthn spec
      external_id: Base64.urlsafe_encode64(SecureRandom.random_bytes(16), padding: false),
      public_key: 'dummy_public_key_for_testing',
      nickname: options[:nickname] || 'Test Security Key',
      sign_count: 0
    )
  end

  def mock_webauthn_assertion(client, options = {})
    challenge = options[:challenge] || SecureRandom.random_bytes(32)

    # Store the challenge in the session using our standard key
    session[TwoFactorAuth::SESSION_KEYS[:challenge]] = challenge
    session[TwoFactorAuth::SESSION_KEYS[:type]] = :webauthn

    # Generate fake assertion response
    client.get(
      challenge: challenge,
      rp_id: URI.parse(client.origin).host,
      user_present: options[:user_present] || true,
      user_verified: options[:user_verified] || true,
      sign_count: options[:sign_count] || 1
    )
  end

  def setup_webauthn_test_environment
    # Configure WebAuthn for testing
    WebAuthn.configure do |config|
      config.allowed_origins = ['https://example.com']
    end

    # Return a fake client for the test environment
    WebAuthn::FakeClient.new('https://example.com')
  end

  # Backwards-compatibility alias used by some system tests
  def create_webauthn_credential_programmatically(user, client, nickname = 'Test Security Key')
    create_fake_credential(user, client, nickname: nickname)
  end
end
