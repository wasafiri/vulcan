# Two-Factor Authentication (2FA) Implementation Guide

This guide explains the standardized approach to two-factor authentication (2FA) in the MAT Vulcan application. It covers all supported methods: WebAuthn (security keys), TOTP (authenticator apps), and SMS (text message).

## Table of Contents
1. [Overview](#overview)
2. [Standardized Session Management](#standardized-session-management)
3. [Authentication Methods](#authentication-methods)
4. [Implementation Details](#implementation-details)
5. [JavaScript Integration](#javascript-integration)
6. [Testing 2FA](#testing-2fa)
7. [Troubleshooting](#troubleshooting)

## Overview

MAT Vulcan supports multiple 2FA methods to provide secure authentication while maintaining flexibility for users:

- **WebAuthn**: Security keys (like YubiKeys) and platform authenticators (like Touch ID or Windows Hello)
- **TOTP**: Time-based One-Time Password apps (like Google Authenticator, Authy)
- **SMS**: Text message verification codes sent to the user's phone

All methods follow a standardized implementation pattern to ensure consistent security and user experience.

## Standardized Session Management

The core of our 2FA implementation is the `TwoFactorAuth` module in `config/initializers/two_factor_auth.rb`, which provides standardized session management:

### Session Keys

All authentication methods use these standard session keys:

```ruby
TwoFactorAuth::SESSION_KEYS[:challenge]    # Stores the authentication challenge
TwoFactorAuth::SESSION_KEYS[:type]         # Stores the authentication type (webauthn, totp, sms)
TwoFactorAuth::SESSION_KEYS[:metadata]     # Stores additional data specific to the authentication method
TwoFactorAuth::SESSION_KEYS[:verified_at]  # Stores the timestamp when 2FA was successfully completed
```

### Helper Methods

The module provides these methods to standardize 2FA flows:

```ruby
# Store a challenge (and relevant metadata) in the session
TwoFactorAuth.store_challenge(session, :type, challenge, metadata)

# Retrieve challenge data from the session
challenge_data = TwoFactorAuth.retrieve_challenge(session)
# Returns { type: :webauthn, challenge: '...', metadata: { ... } }

# Clear challenge data from the session (after verification)
TwoFactorAuth.clear_challenge(session)

# Mark the session as verified (after successful 2FA)
TwoFactorAuth.mark_verified(session)

# Check if a session is verified
TwoFactorAuth.verified?(session)

# Logging helpers for auditing
TwoFactorAuth.log_verification_success(user_id, :method)
TwoFactorAuth.log_verification_failure(user_id, :method, error_message)
```

## Authentication Methods

### WebAuthn (Security Keys)

WebAuthn provides the highest security level using cryptographic authenticators:

1. **Registration Flow**:
   - Generate credential options (`WebAuthnCredentialsController#options`)
   - Store challenge with `TwoFactorAuth.store_challenge`
   - Create credential with browser API (`credential.js#create`)
   - Verify challenge and save credential

2. **Authentication Flow**:
   - Generate assertion options (`WebAuthnCredentialAuthenticationsController#options`)
   - Store challenge with `TwoFactorAuth.store_challenge`
   - Get assertion with browser API (`credential.js#get`)
   - Verify challenge and mark session as verified

See `doc/webauthn_guide.md` for detailed information about WebAuthn implementation.

### TOTP (Authenticator Apps)

TOTP uses time-based codes that change every 30 seconds:

1. **Registration Flow**:
   - Generate TOTP secret (`TotpCredentialsController#new`)
   - Store secret in session with `TwoFactorAuth.store_challenge`
   - Display QR code for user to scan
   - Verify initial code and save credential

2. **Authentication Flow**:
   - User enters code from their authenticator app
   - Verify code against stored secrets (`verify_totp_code`)
   - Mark session as verified

### SMS (Text Message)

SMS sends verification codes to the user's phone:

1. **Registration Flow**:
   - Collect and verify phone number (`SmsCredentialsController#create`)
   - Generate and send verification code
   - Store code digest with `TwoFactorAuth.store_challenge`
   - Verify code entered by user

2. **Authentication Flow**:
   - Generate and send verification code
   - Store code digest with `TwoFactorAuth.store_challenge`
   - Verify code entered by user
   - Mark session as verified

## Implementation Details

### Controllers

Each authentication method has dedicated controllers:

- **WebAuthn**: `WebauthnCredentialsController` and `WebauthnCredentialAuthenticationsController`
- **TOTP**: `TotpCredentialsController`
- **SMS**: `SmsCredentialsController`

These controllers implement the method-specific logic while using the standardized session management.

### Unified 2FA Flow

The `TwoFactorAuthenticationsController` coordinates the overall 2FA flow, showing available methods and verifying codes.

Example credential verification code:

```ruby
def verify_code
  # Get method and code from params
  method = params[:method]
  code = params[:code]
  
  # Verify based on method type
  if method == 'totp'
    result = verify_totp_code(code)
  elsif method == 'sms'
    result = verify_sms_code(code)
  end
  
  if result
    # Mark session as verified
    TwoFactorAuth.mark_verified(session)
    redirect_to stored_location_for(:user) || root_path
  else
    flash.now[:alert] = TwoFactorAuth::ERROR_MESSAGES[:invalid_code]
    render :verify
  end
end
```

## JavaScript Integration

The `credential.js` module provides unified JavaScript functions for all authentication methods:

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

This ensures consistent error handling and user feedback across all authentication methods.

## Testing 2FA

### Test Files

- `test/lib/two_factor_auth_test.rb`: Tests the core session management methods
- `test/controllers/webauthn_credentials_controller_test.rb`: Tests WebAuthn credential creation
- `test/system/webauthn_sign_in_test.rb`: System tests for WebAuthn sign-in flow
- `test/system/two_factor_authentication_flow_test.rb`: System tests for the overall 2FA flow

### Test Helpers

The `WebauthnTestHelper` module provides helpers for testing WebAuthn functionality:

```ruby
include WebauthnTestHelper

def setup
  @fake_client = setup_webauthn_test_environment
end
```

When testing TOTP and SMS methods, use fixed codes and mock the SMS service:

```ruby
# Mock SMS service in tests
SMSService.stubs(:send_message).returns(true)

# Use fixed TOTP secret for tests
@secret = "ABCDEFGHIJKLMNOP"
ROTP::TOTP.new(@secret).verify('123456')
```

## Troubleshooting

### Common Issues

1. **Session Challenge Mismatch**
   - Ensure challenge is stored using `TwoFactorAuth.store_challenge`
   - Verify the challenge is retrieved correctly before verification
   - Check that challenge is only cleared after successful verification

2. **Authentication Method Not Working**
   - Check browser console for JavaScript errors
   - Verify the correct session keys are being used
   - Confirm the credential exists in the database

3. **WebAuthn Specific Issues**
   - See `doc/webauthn_guide.md` for WebAuthn-specific troubleshooting

### Error Messages

Standard error messages are defined in `TwoFactorAuth::ERROR_MESSAGES`:

```ruby
TwoFactorAuth::ERROR_MESSAGES[:invalid_code]
TwoFactorAuth::ERROR_MESSAGES[:expired_code]
TwoFactorAuth::ERROR_MESSAGES[:missing_credential]
TwoFactorAuth::ERROR_MESSAGES[:webauthn_challenge_mismatch]
```

Use these consistently for a unified user experience.

### Logging

Authentication successes and failures are logged with:

```ruby
TwoFactorAuth.log_verification_success(user_id, :method)
TwoFactorAuth.log_verification_failure(user_id, :method, error_message)
```

Check the logs for detailed information about authentication issues.
