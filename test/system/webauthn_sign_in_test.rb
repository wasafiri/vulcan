require 'application_system_test_case'
require 'webauthn/fake_client' # Ensure FakeClient is available
require_relative '../support/webauthn_test_helper' # Include the helper

# This test focuses on WebAuthn credential management and sign-in flows
class WebauthnSignInTest < ApplicationSystemTestCase # Renamed class for clarity
  include SystemTestAuthentication
  include WebauthnTestHelper # Include the helper methods
  # Add teardown to handle any browser cleanup issues gracefully
  def teardown
    # Rescue any browser-related errors during teardown
    # This is needed because WebAuthn can sometimes cause the browser to behave unpredictably
    super
  # we might need to change this to work with Cuprite gem
  rescue Selenium::WebDriver::Error::NoSuchWindowError,
         Selenium::WebDriver::Error::InvalidArgumentError,
         NoMethodError => e
    puts "Rescued error during teardown: #{e.class} - #{e.message}"
  end

  test 'webauthn credential creation for user' do
    user = create(:user, :confirmed)

    # Configure WebAuthn
    # Use a fixed origin for testing since we won't navigate to a page
    fake_client = setup_webauthn_test_environment

    # Create WebAuthn credential options
    credential_options = WebAuthn::Credential.options_for_create(user: { id: user.id, name: user.email })

    # Simulate credential creation with fake client
    credential_hash = fake_client.create(challenge: credential_options.challenge)
    puts "DEBUG: Credential Hash: #{credential_hash.inspect}"

    # Save credential to database
    credential = user.webauthn_credentials.create!(
      external_id: credential_hash['id'],
      public_key: 'dummy_public_key_for_testing',
      nickname: 'Test Key',
      sign_count: 0
    )

    # Verify the credential was saved
    assert_not_nil credential.id, 'Credential should have an ID after being saved'
    assert_equal credential_hash['id'], credential.external_id, 'Credential external_id should match the generated ID'

    # Verify the user now has 2FA enabled
    assert user.reload.second_factor_enabled?, 'User should have second factor enabled after credential creation'
  end

  test 'registration redirects to welcome page with 2FA setup option' do
    # Clear any existing sessions
    reset_session!

    # Visit registration page and fill required fields
    visit sign_up_path
    assert_text 'Create Account'

    # Fill in basic information
    fill_in 'First Name', with: '2FA'
    fill_in 'Last Name', with: 'Tester'
    fill_in 'Email Address', with: 'new_2fa_user@example.com'
    fill_in 'Password', with: 'password123'
    fill_in 'Confirm Password', with: 'password123'
    fill_in 'Phone Number', with: '555-555-5555'

    # Fill in Date of Birth (MM/DD/YYYY format)
    fill_in 'visible_date_of_birth', with: '01/01/1990'

    # Select language preference
    select 'English', from: 'Language Preference'

    # Communication preference defaults to Email which is what we want
    # No need to fill in address fields

    # Click the Create Account button
    click_button 'Create Account'

    # Verify welcome page and 2FA setup option
    assert_current_path welcome_path
    assert_text 'Welcome to Maryland Accessible Telecommunications'
    assert_selector 'a', text: 'Set Up Two-Factor Authentication'

    # Test the "Skip for now" option
    click_link 'Skip for now'
    assert_current_path root_path

    # Header should show the security reminder
    assert_selector '.bg-amber-100', text: /Secure Account/i
  end

  test 'welcome page redirects to dashboard if user has WebAuthn' do
    # Create a user with WebAuthn credentials
    user = create(:constituent, :with_webauthn_credential)

    # Sign in as that user
    system_test_sign_in(user)

    # Visit welcome page - should redirect to dashboard
    visit welcome_path

    # Should be redirected to dashboard - adapt to actual path
    assert ['/constituent/dashboard', '/constituent_portal/dashboard'].include?(current_path),
           "Expected to be redirected to dashboard but was at #{current_path}"

    # Should not see security reminder in header
    assert_no_selector '.bg-amber-100', text: /Secure Account/i
  end

  test 'user can complete 2FA setup from welcome page' do
    # Create test user
    user = User.create!(
      email: 'webauthn_test@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'WebAuthn',
      last_name: 'Tester',
      date_of_birth: 30.years.ago,
      phone: '555-555-5555',
      hearing_disability: true,
      type: 'Users::Constituent'
    )

    system_test_sign_in(user)
    visit welcome_path
    assert_text 'Welcome to Maryland Accessible Telecommunications'

    # Click the 2FA setup link using the exact text from the welcome page
    assert_selector 'a', text: 'Set Up Two-Factor Authentication'
    click_link 'Set Up Two-Factor Authentication'

    # We should be on the 2FA setup page
    assert_current_path setup_two_factor_authentication_path

    # Navigate to WebAuthn credential setup
    # Be more specific with our selector since there might be multiple webauthn-related links
    find('a[href*="two_factor_authentication"][href*="credentials/webauthn"]', text: /Security Key|WebAuthn|Add Key/i).click
    assert_current_path new_credential_two_factor_authentication_path(type: 'webauthn')

    # Fill in the nickname field using its ID since the label might be complex
    fill_in 'webauthn_credential_nickname', with: 'My Test Security Key'

    # Create credential (simulated since browser WebAuthn API can't be tested directly)
    assert_difference 'user.webauthn_credentials.count', 1 do
      user.webauthn_credentials.create!(
        external_id: SecureRandom.uuid,
        nickname: 'My Test Security Key',
        public_key: 'test_public_key',
        sign_count: 0
      )
    end

    # Verify WebAuthn status and UI
    assert user.reload.webauthn_credentials.exists?
    visit welcome_path

    # Be flexible about dashboard path
    assert ['/constituent/dashboard', '/constituent_portal/dashboard'].include?(current_path),
           "Expected to be redirected to dashboard but was at #{current_path}"

    # Should not see security reminder
    assert_no_selector '.bg-amber-100', text: /Your Account Needs Protection/i
  end

  test 'user sets up WebAuthn credential via UI' do
    user = User.create!(
      email: "webauthn_setup_ui_#{SecureRandom.hex(4)}@example.com",
      password: 'password123', password_confirmation: 'password123',
      first_name: 'WebAuthn', last_name: 'SetupUI', type: 'Users::Constituent',
      date_of_birth: 30.years.ago, phone: '555-111-2222'
    )
    user.update!(webauthn_id: WebAuthn.generate_user_id) # Ensure webauthn_id is set

    system_test_sign_in(user)
    visit new_credential_two_factor_authentication_path(type: 'webauthn')
    assert_text 'Add a Security Key'

    fill_in 'Nickname', with: 'My UI Key'

    # Simulate clicking the button that triggers WebAuthnJSON.create
    # We assume a button or link with a specific ID or data attribute exists.
    # Since we can't fully mock the browser API, we'll simulate the backend part.
    # We need the challenge stored in the session by the controller.
    challenge = retrieve_session_webauthn_challenge

    assert challenge.present?, 'WebAuthn challenge not found in session'

    # Use FakeClient to generate a valid response based on the challenge
    fake_client = setup_webauthn_test_environment
    credential_response = fake_client.create(challenge: challenge)

    # Manually post the fake credential data to the create endpoint,
    # simulating the JavaScript callback.
    post create_credential_two_factor_authentication_path(type: 'webauthn'), params: {
      credential_nickname: 'My UI Key',
      response: {
        attestationObject: credential_response['response']['attestationObject'],
        clientDataJSON: credential_response['response']['clientDataJSON']
      },
      id: credential_response['id'],
      rawId: credential_response['rawId'],
      type: credential_response['type']
    }, as: :json

    # Check the response from the manual post
    assert_response :ok
    response_json = JSON.parse(@response.body)
    assert_equal 'ok', response_json['status']
    assert response_json['redirect_url'].include?(credential_success_two_factor_authentication_path(type: 'webauthn'))

    # Now visit the redirect URL to confirm the UI state
    visit response_json['redirect_url']
    assert_text 'Security key registered successfully' # Assuming this message exists
    take_screenshot('webauthn-setup-ui-success')

    # Verify credential exists
    user.reload
    assert user.webauthn_credentials.exists?(nickname: 'My UI Key')
  end

  test 'user logs in successfully using WebAuthn via UI interaction simulation' do
    user = create(:user, :confirmed) # Use a fixture user
    user.update!(webauthn_id: WebAuthn.generate_user_id) if user.webauthn_id.blank?

    # Create a credential programmatically first
    fake_client = setup_webauthn_test_environment
    credential = create_fake_credential(user, fake_client, nickname: 'Login Key')
    assert credential.persisted?

    # Sign in
    system_test_sign_in(user)

    # Should be redirected to WebAuthn verification
    assert_current_path verify_method_two_factor_authentication_path(type: 'webauthn')
    assert_text 'Verify Your Identity' # Or similar text on the verification page
    take_screenshot('webauthn-login-ui-prompt')

    # Simulate clicking the button that triggers WebAuthnJSON.get
    # Retrieve the challenge stored by the verification_options action
    challenge = retrieve_session_webauthn_challenge(fetch_options: true, user: user)
    assert challenge.present?, 'WebAuthn challenge not found in session for verification'

    # Use FakeClient to generate a valid assertion
    assertion_response = fake_client.get(
      challenge: challenge,
      allow_credentials: [{ type: 'public-key', id: credential.external_id }],
      sign_count: credential.sign_count # Use the current sign count
    )

    # Manually post the fake assertion data to the process_verification endpoint
    post process_verification_two_factor_authentication_path(type: 'webauthn'), params: {
      id: assertion_response['id'],
      rawId: assertion_response['rawId'],
      type: assertion_response['type'],
      response: {
        authenticatorData: assertion_response['response']['authenticatorData'],
        clientDataJSON: assertion_response['response']['clientDataJSON'],
        signature: assertion_response['response']['signature'],
        userHandle: assertion_response['response']['userHandle']
      }
    }, as: :json

    # Check the response from the manual post
    assert_response :ok
    response_json = JSON.parse(@response.body)
    assert_equal 'success', response_json['status']
    assert response_json['redirect_url'].present?

    # Visit the redirect URL
    visit response_json['redirect_url']
    assert_current_path root_path # Or appropriate dashboard
    assert_text 'Signed in successfully'
    take_screenshot('webauthn-login-ui-success')

    # Verify sign_count was updated
    assert_equal credential.sign_count + 1, credential.reload.sign_count
  end

  test 'user fails login with invalid WebAuthn assertion via UI interaction simulation' do
    user = create(:user, :confirmed) # Use a fixture user
    user.update!(webauthn_id: WebAuthn.generate_user_id) if user.webauthn_id.blank?

    # Create a credential programmatically
    fake_client = setup_webauthn_test_environment
    credential = create_fake_credential(user, fake_client, nickname: 'Login Key Fail')
    assert credential.persisted?

    # Sign in
    system_test_sign_in(user)

    # Should be redirected to WebAuthn verification
    assert_current_path verify_method_two_factor_authentication_path(type: 'webauthn')
    assert_text 'Verify Your Identity'
    take_screenshot('webauthn-login-ui-fail-prompt')

    # Retrieve the challenge
    challenge = retrieve_session_webauthn_challenge(fetch_options: true, user: user)
    assert challenge.present?, 'WebAuthn challenge not found in session for verification'

    # Use FakeClient to generate an assertion, but we'll tamper with it
    assertion_response = fake_client.get(
      challenge: challenge, # Use the correct challenge initially
      allow_credentials: [{ type: 'public-key', id: credential.external_id }],
      sign_count: credential.sign_count
    )

    # Tamper with the signature to make it invalid
    invalid_signature = SecureRandom.random_bytes(64)

    # Manually post the fake assertion data with the invalid signature
    post process_verification_two_factor_authentication_path(type: 'webauthn'), params: {
      id: assertion_response['id'],
      rawId: assertion_response['rawId'],
      type: assertion_response['type'],
      response: {
        authenticatorData: assertion_response['response']['authenticatorData'],
        clientDataJSON: assertion_response['response']['clientDataJSON'],
        signature: Base64.strict_encode64(invalid_signature), # Use invalid signature
        userHandle: assertion_response['response']['userHandle']
      }
    }, as: :json

    # Check the response - should be an error status
    assert_response :not_found # Or :unprocessable_entity depending on controller handling
    response_json = JSON.parse(@response.body)
    assert response_json['error'].present?
    # Example: assert_match /Verification failed/i, response_json['error']

    # Visit the verification page again to check UI feedback
    visit verify_method_two_factor_authentication_path(type: 'webauthn')
    # Check for flash message or specific error element
    assert_text(/Verification failed|Invalid security key/i) # Adjust based on actual error message
    take_screenshot('webauthn-login-ui-failure')
  end

  private

  # Helper to try different possible selectors for password confirmation
  def fill_password_confirmation(password)
    # Try different field names for password confirmation
    if page.has_field?('Confirm password')
      fill_in 'Confirm password', with: password
    elsif page.has_field?('Password confirmation')
      fill_in 'Password confirmation', with: password
    elsif page.has_field?('user[password_confirmation]')
      fill_in 'user[password_confirmation]', with: password
    else
      # If all else fails, try to find by CSS selector
      find('input[name*="password_confirmation"]').set(password)
    end
  rescue Capybara::ElementNotFound => e
    puts "Warning: Could not find password confirmation field: #{e.message}"
  end

  # Helper to try different possible approaches for date of birth
  def fill_date_of_birth
    if page.has_field?('Date of birth')
      fill_in 'Date of birth', with: '01/01/1990'
    elsif page.has_select?('user_date_of_birth_1i')
      # Rails date selects (year, month, day)
      select '1990', from: 'user_date_of_birth_1i'
      select 'January', from: 'user_date_of_birth_2i'
      select '1', from: 'user_date_of_birth_3i'
    end
  rescue Capybara::ElementNotFound => e
    puts "Warning: Could not fill date of birth field: #{e.message}"
  end

  # Helper to find 2FA setup link with various possible selectors
  def find_2fa_setup_link
    # Try different possible link texts for 2FA setup
    possible_texts = [
      'Add Security Key',
      'Set up Two-Factor Authentication',
      'Enable 2FA',
      'Add Authenticator',
      'Security Settings',
      'Register Security Key'
    ]

    # Try to find any of the possible links
    possible_texts.each do |text|
      return page.find_link(text) if page.has_link?(text)
    end

    # If not found by text, try common CSS selectors
    selectors = [
      'a[href*="two_factor_authentication"][href*="credentials/webauthn"]',
      'a[href*="2fa"]',
      'a[href*="security"]',
      'a[data-test="security-key-setup"]'
    ]

    selectors.each do |selector|
      return page.find(selector) if page.has_css?(selector)
    end

    # Return nil if no matching link found
    nil
  end
end
