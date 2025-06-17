# frozen_string_literal: true

module TwoFactorVerification
  extend ActiveSupport::Concern

  protected

  # Challenge management methods (Now directly using TwoFactorAuth module)
  def store_challenge(type, challenge, metadata = {})
    TwoFactorAuth.store_challenge(session, type, challenge, metadata)
  end

  def retrieve_challenge
    TwoFactorAuth.retrieve_challenge(session)
  end

  def clear_challenge
    TwoFactorAuth.clear_challenge(session)
  end

  # Verification result methods
  def complete_verification(_user_id, _type)
    # Log successful verification (using TwoFactorAuth module)
    # Note: The log_verification_success/failure methods below already call the module
    # TwoFactorAuth.log_verification_success(user_id, type) # Redundant call

    # Complete the authentication process (using TwoFactorAuth module)
    TwoFactorAuth.complete_authentication(session)
  end

  # These methods already call the TwoFactorAuth module directly
  # def log_verification_success(user_id, type)
  #   TwoFactorAuth.log_verification_success(user_id, type)
  # end
  #
  # def log_verification_failure(user_id, type, error)
  #   TwoFactorAuth.log_verification_failure(user_id, type, error)
  # end

  # Updated log calls within verification methods to pass context hash
  def log_verification_success(user_id, type, context = {})
    TwoFactorAuth.log_verification_success(user_id, type, context)
  end

  def log_verification_failure(user_id, type, error, context = {})
    TwoFactorAuth.log_verification_failure(user_id, type, error, context)
  end

  # Unified verification methods that delegate to type-specific handlers
  def verify_credential(type, params)
    case type.to_sym
    when :webauthn
      verify_webauthn_credential(params)
    when :totp
      verify_totp_credential(params[:code])
    when :sms
      verify_sms_credential(params[:code], params[:credential_id])
    else
      [false, 'Invalid credential type']
    end
  end

  def verify_webauthn_credential(params)
    user_for_2fa = find_user_for_two_factor
    return [false, 'User session not found'] unless user_for_2fa

    webauthn_credential = WebAuthn::Credential.from_get(params)
    stored_credential = user_for_2fa.webauthn_credentials.find_by(external_id: webauthn_credential.id)
    return [false, 'Credential not found'] unless stored_credential

    begin
      challenge = retrieve_challenge[:challenge]
      webauthn_credential.verify(
        challenge,
        public_key: stored_credential.public_key,
        sign_count: stored_credential.sign_count
      )

      stored_credential.update!(sign_count: webauthn_credential.sign_count)
      log_verification_success(user_for_2fa.id, :webauthn, credential_id: stored_credential.id)
      [true, 'Verification successful']
    rescue WebAuthn::Error => e
      log_verification_failure(user_for_2fa.id, :webauthn, e.message, credential_id: stored_credential&.id)
      [false, "Verification failed: #{e.message}"]
    end
  end

  def verify_totp_credential(code)
    return [false, 'No code provided'] if code.blank?

    user_for_2fa = find_user_for_two_factor
    return [false, 'User session not found'] unless user_for_2fa

    user_for_2fa.totp_credentials.each do |credential|
      totp = ROTP::TOTP.new(credential.secret)
      next unless totp.verify(code, drift_behind: 30, drift_ahead: 30)

      credential.update(last_used_at: Time.current)
      log_verification_success(user_for_2fa.id, :totp, credential_id: credential.id)
      return [true, 'Verification successful']
    end

    log_verification_failure(user_for_2fa.id, :totp, 'Invalid code', credential_ids: user_for_2fa.totp_credentials.pluck(:id))
    [false, TwoFactorAuth::ERROR_MESSAGES[:invalid_code]]
  end

  def verify_sms_credential(code, credential_id)
    return [false, 'No code provided'] if code.blank?

    # Use credential_id if provided, otherwise use challenge data
    if credential_id.blank?
      challenge_data = retrieve_challenge
      credential_id = challenge_data[:metadata]&.dig(:credential_id)
      return [false, 'No credential found'] if credential_id.blank?
    end

    credential = current_user.sms_credentials.find_by(id: credential_id)
    return [false, 'Credential not found'] if credential.nil?

    # Check expiration
    if credential.code_digest.blank? || credential.code_expires_at < Time.current
      return [false, 'Code expired']
    end

    # Verify code using the model method
    if credential.verify_code(code)
      clear_challenge
      log_verification_success(current_user.id, :sms, credential_id: credential.id)
      return [true, 'Verification successful']
    else
      log_verification_failure(current_user.id, :sms, 'Invalid code', credential_id: credential.id)
      [false, TwoFactorAuth::ERROR_MESSAGES[:invalid_code]]
    end
  end

  # Error handling methods
  def handle_verification_error(error, type, format = :html)
    error_message = get_friendly_error_message(error, type)
    log_verification_failure(current_user.id, type, error_message)

    if format == :json || request.xhr?
      render json: { error: error_message, details: error.message }, status: :unprocessable_entity
    else
      flash.now[:alert] = error_message
      render :new
    end
  end

  def get_friendly_error_message(error, type)
    case type
    when :webauthn
      case error.message
      when /challenge/i
        TwoFactorAuth::ERROR_MESSAGES[:webauthn_challenge_mismatch]
      when /already registered/i
        'This security key is already registered with your account.'
      when /user verification/i
        'Your device rejected the verification. Please ensure your fingerprint or PIN is set up correctly.'
      else
        "Verification failed: #{error.message}"
      end
    else
      TwoFactorAuth::ERROR_MESSAGES[:invalid_code]
    end
  end
end
