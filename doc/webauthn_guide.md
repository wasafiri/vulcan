# WebAuthn Implementation Guide

This guide explains how WebAuthn (Web Authentication) is implemented and used in the MAT Vulcan application to provide secure passwordless authentication and two-factor authentication (2FA).

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Configuration](#configuration)
4. [Standardized Authentication Flow](#standardized-authentication-flow)
5. [Frontend Implementation](#frontend-implementation)
6. [Backend Implementation](#backend-implementation)
7. [Testing WebAuthn](#testing-webauthn)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

## Overview

WebAuthn is a web standard for passwordless authentication that allows users to authenticate using hardware security keys, platform authenticators (like Touch ID, Face ID, or Windows Hello), or other FIDO2-compliant devices. In MAT Vulcan, WebAuthn is used to:

- Enable secure two-factor authentication (2FA)
- Provide a more secure authentication mechanism than passwords alone
- Simplify the login experience for users with compatible devices

## Architecture

Our WebAuthn implementation consists of:

1. **Backend Components**:
   - The `webauthn-ruby` gem for handling WebAuthn operations
   - `WebauthnCredential` model for storing user credentials
   - Controllers for credential registration and authentication
   - The `TwoFactorAuth` module for standardized session management

2. **Frontend Components**:
   - JavaScript controllers using Stimulus
   - Integration with the WebAuthn browser API
   - User interface elements for credential management

## Configuration

WebAuthn is configured in `config/initializers/webauthn.rb`:

```ruby
WebAuthn.configure do |config|
  config.allowed_origins = [ENV["WEBAUTHN_ORIGIN"]]
  config.rp_name = "MAT Vulcan"
end
```

The `WEBAUTHN_ORIGIN` environment variable must match your application's domain (e.g., `https://your-app-domain.com`) to comply with WebAuthn's same-origin policy. In development, this is typically set to your local server (e.g., `http://localhost:3000`).

## Standardized Authentication Flow

We use a standardized approach for all 2FA methods (WebAuthn, TOTP, SMS) via the `TwoFactorAuth` module in `config/initializers/two_factor_auth.rb`:

### Session Management

The module defines standard session keys for storing challenges and verification state:

```ruby
# Standard session keys
TwoFactorAuth::SESSION_KEYS[:challenge]   # :two_factor_challenge
TwoFactorAuth::SESSION_KEYS[:type]        # :two_factor_type
TwoFactorAuth::SESSION_KEYS[:metadata]    # :two_factor_metadata
TwoFactorAuth::SESSION_KEYS[:verified_at] # :two_factor_verified_at
```

### Helper Methods

The module provides these key methods for all 2FA flows:

```ruby
# Store challenge in session
TwoFactorAuth.store_challenge(session, :webauthn, challenge, { metadata: 'data' })

# Retrieve challenge data from session
challenge_data = TwoFactorAuth.retrieve_challenge(session)
# => { type: :webauthn, challenge: '...', metadata: { ... } }

# Clear challenge from session
TwoFactorAuth.clear_challenge(session)

# Mark session as verified after successful authentication
TwoFactorAuth.mark_verified(session)

# Check if session is verified
TwoFactorAuth.verified?(session)

# Logging helpers
TwoFactorAuth.log_verification_success(user_id, :webauthn)
TwoFactorAuth.log_verification_failure(user_id, :webauthn, error_message)
```

This standardized flow makes the code more maintainable and ensures consistent security across all authentication methods.

## Frontend Implementation

The frontend implementation uses Stimulus controllers to integrate with the WebAuthn API:

### Add Credential Controller

The `add_credential_controller.js` handles the credential creation process:

1. Requests credential creation options from the server
2. Passes these options to the browser's WebAuthn API
3. Sends the resulting credential to the server for verification and storage

### Credential Authenticator Controller

The `credential_authenticator_controller.js` handles the authentication process:

1. Automatically requests authentication options when the login page loads
2. Passes these options to the browser's WebAuthn API
3. Sends the resulting assertion to the server for verification

### Unified JavaScript

The `credential.js` module provides standardized functions for all authentication types:

```javascript
// WebAuthn operations
create(callbackUrl, credentialOptions, feedbackElement)
get(credentialOptions, callbackUrl, feedbackElement)

// TOTP verification
verifyTotpCode(code, callbackUrl, feedbackElement)

// SMS operations
verifySmsCode(code, callbackUrl, feedbackElement)
requestSmsCode(url, feedbackElement)
```

This unified approach ensures consistent error handling and user feedback across all authentication methods.

## Backend Implementation

The backend implementation handles credential creation, storage, and verification:

### WebauthnCredential Model

This model stores the user's WebAuthn credentials:

- `external_id`: The credential ID as provided by the authenticator
- `public_key`: The credential's public key used for verification
- `nickname`: A user-friendly name for the credential
- `sign_count`: A counter used to prevent replay attacks

### Controllers

- `WebauthnCredentialsController`: Handles credential creation and management
- `WebauthnCredentialAuthenticationController`: Handles authentication with WebAuthn
- `TwoFactorAuthenticationsController`: Manages the overall 2FA flow

Example of using the standardized flow in a controller:

```ruby
# Store challenge during credential creation
TwoFactorAuth.store_challenge(
  session,
  :webauthn,
  create_options.challenge,
  { authenticator_type: authenticator_type }
)

# Retrieve and verify challenge during authentication
challenge_data = TwoFactorAuth.retrieve_challenge(session)
challenge = challenge_data[:challenge]
webauthn_credential.verify(challenge)

# Clear challenge after verification
TwoFactorAuth.clear_challenge(session)

# Mark as verified after successful authentication
TwoFactorAuth.mark_verified(session)
```

## Testing WebAuthn

Testing WebAuthn presents unique challenges because it interacts with platform-specific APIs and hardware. We use the `webauthn-ruby` gem's fake client to simulate WebAuthn authentication in tests.

### System Tests

For system tests, we use a focused approach that tests the core WebAuthn functionality without relying on browser interactions:

1. **Credential Creation**: Tests that WebAuthn credentials can be created and associated with users
2. **Credential Verification**: Tests that credentials are properly verified
3. **User Status**: Tests that user's second factor status is properly updated

See the `test/system/webauthn_sign_in_test.rb` file for an example test implementation.

### WebAuthn Test Helpers

When testing WebAuthn, use the following practices:

- Implement proper teardown handling for browser sessions
- Use fixed origins for testing (e.g., "https://example.com")
- Avoid testing complex browser interactions in WebAuthn tests
- Focus on credential creation and verification logic

### Testing Challenge Management

Use the tests in `test/lib/two_factor_auth_test.rb` as a reference for testing challenge storage and verification:

```ruby
test 'stores a webauthn challenge' do
  challenge = SecureRandom.hex(16)
  stored_challenge = TwoFactorAuth.store_challenge(
    @session, 
    :webauthn,
    challenge, 
    { authenticator_type: 'cross-platform' }
  )
  
  assert_equal challenge, stored_challenge
  assert_equal :webauthn, @session[TwoFactorAuth::SESSION_KEYS[:type]]
  assert_equal challenge, @session[TwoFactorAuth::SESSION_KEYS[:challenge]]
end
```

## Troubleshooting

### Common Issues

#### Incorrect Origin

If you see "The operation either timed out or was not allowed" errors, check that your `WEBAUTHN_ORIGIN` environment variable matches your application's domain exactly.

#### Browser Support

WebAuthn requires a modern browser. Ensure your users are using:
- Chrome 67+
- Firefox 60+
- Edge 18+
- Safari 13+

#### Insecure Context

WebAuthn requires a secure context (HTTPS) in production. In development, localhost is considered a secure context.

#### Session Management

If authentication is failing with challenge mismatch errors, verify:
- Challenge is being properly stored using `TwoFactorAuth.store_challenge`
- Challenge is being retrieved with `TwoFactorAuth.retrieve_challenge` before verification
- Challenge is being cleared with `TwoFactorAuth.clear_challenge` after verification

## Best Practices

1. **Provide Alternative Authentication**: Always offer an alternative authentication method for users without WebAuthn support
2. **Clear Error Messages**: Provide specific, user-friendly error messages for WebAuthn operations
3. **Credential Management**: Allow users to manage their security keys, including adding, renaming, and removing them
4. **Backwards Compatibility**: Support both WebAuthn and traditional authentication methods during transition periods
5. **Progressive Enhancement**: Implement WebAuthn as a progressive enhancement, not a requirement
6. **Standardized Flow**: Use the standardized `TwoFactorAuth` module for all authentication methods to ensure consistent security
7. **Logging**: Use the logging helpers to track authentication successes and failures
