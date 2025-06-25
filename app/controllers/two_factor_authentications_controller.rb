# frozen_string_literal: true

class TwoFactorAuthenticationsController < ApplicationController
  include TwoFactorVerification

  before_action :authenticate_user!
  skip_before_action :authenticate_user!, only: %i[verify verify_method process_verification verification_options setup]

  # GET /two_factor_authentication/setup
  def setup
    # Handle both authenticated users and users in 2FA flow
    @user = current_user || find_user_for_two_factor

    unless @user
      redirect_to sign_in_path
      return
    end

    # Check for existing credentials
    @has_webauthn = @user.webauthn_credentials.exists?
    @has_totp = @user.totp_credentials.exists?
    @has_sms = @user.sms_credentials.exists?

    # If user already has any 2FA method set up and force param is not present, redirect appropriately
    return unless (@has_webauthn || @has_totp || @has_sms) && params[:force] != 'true'

    if current_user
      # Fully authenticated user
      redirect_to edit_profile_path, notice: 'Your account is already secured with two-factor authentication.'
    elsif @has_totp
      # User in 2FA flow - redirect to appropriate verification method
      redirect_to verify_method_two_factor_authentication_path(type: 'totp')
    elsif @has_sms
      redirect_to verify_method_two_factor_authentication_path(type: 'sms')
    elsif @has_webauthn
      redirect_to verify_method_two_factor_authentication_path(type: 'webauthn')
    end
  end

  # GET /two_factor_authentication/verify
  def verify
    # Handle both authenticated users and users in 2FA flow
    @user = current_user || find_user_for_two_factor

    unless @user
      redirect_to sign_in_path
      return
    end

    # Check if user has 2FA enabled
    unless @user.second_factor_enabled?
      redirect_to setup_two_factor_authentication_path
      return
    end

    # Set available methods
    @webauthn_enabled = @user.webauthn_credentials.exists?
    @totp_enabled = @user.totp_credentials.exists?
    @sms_enabled = @user.sms_credentials.exists?

    # If only one method is available, redirect directly to it
    available_methods = [@webauthn_enabled, @totp_enabled, @sms_enabled].count(true)
    return unless available_methods == 1

    if @totp_enabled
      redirect_to verify_method_two_factor_authentication_path(type: 'totp')
    elsif @sms_enabled
      redirect_to verify_method_two_factor_authentication_path(type: 'sms')
    elsif @webauthn_enabled
      redirect_to verify_method_two_factor_authentication_path(type: 'webauthn')
    end
    nil

    # If multiple methods available, show choice screen
    # The view will be rendered automatically
  end

  # POST /two_factor_authentication/verify_code
  def verify_code
    # Get the method and code from params
    method = params[:method]
    code = params[:code]
    result = false

    # Verify based on method type
    if method == 'totp'
      result = verify_totp_code(code)
    elsif method == 'sms'
      result = verify_sms_code(code)
    end

    if result
      complete_authentication
    else
      flash.now[:alert] = TwoFactorAuth::ERROR_MESSAGES[:invalid_code]
      render :verify
    end
  end

  # Unified methods

  # GET /two_factor_authentication/verify/:type
  def verify_method
    @type = params[:type]

    # Ensure authentication flow and find the user
    return unless authenticate_two_factor_flow

    # Set instance variables needed by the views
    @webauthn_enabled = @user.webauthn_credentials.exists?
    @totp_enabled = @user.totp_credentials.exists?
    @sms_enabled = @user.sms_credentials.exists?
    # Determine if platform authenticator is available (example logic, adjust as needed)
    @platform_key_available = @user.webauthn_credentials.where(authenticator_type: 'platform').exists?

    # Render the appropriate verification template based on type
    render_verification_template(@type)
  end

  # Authenticate the two-factor flow
  def authenticate_two_factor_flow
    unless two_factor_auth_in_progress?
      redirect_to sign_in_path
      return false
    end

    @user = find_user_for_two_factor
    unless @user
      redirect_to sign_in_path
      return false
    end

    true
  end

  # Render the appropriate verification template based on type
  def render_verification_template(type)
    case type
    when 'webauthn'
      if @webauthn_enabled
        render 'verify_webauthn', layout: 'application'
      else
        redirect_to setup_two_factor_authentication_path,
                    alert: 'No security keys are registered. Please set up a security key first.'
      end
    when 'totp'
      if @totp_enabled
        render 'verify_totp', layout: 'application'
      else
        redirect_to setup_two_factor_authentication_path,
                    alert: 'No authenticator app is set up. Please set up TOTP authentication first.'
      end
    when 'sms'
      handle_sms_verification
    else
      redirect_to verify_two_factor_authentication_path,
                  alert: 'Invalid verification method'
    end
  end

  # Handle SMS verification specifically
  def handle_sms_verification
    if @user.sms_credentials.exists?
      credential = @user.sms_credentials.first
      send_sms_verification_code(credential)
      render 'verify_sms', layout: 'application'
    else
      redirect_to verify_two_factor_authentication_path,
                  alert: 'SMS verification not available'
    end
  end

  # POST /two_factor_authentication/verify/:type
  def process_verification
    @type = params[:type]

    # Use the appropriate params based on type
    verification_params = if @type == 'webauthn'
                            webauthn_verification_params.to_h
                          else
                            params
                          end

    success, message = verify_credential(@type, verification_params)

    respond_to do |format|
      if success
        # Get the user for 2FA - this is needed to create the actual session
        @user = find_user_for_two_factor

        # Complete the authentication process
        format.html { complete_two_factor_authentication(@user) }
        format.json do
          # Create the permanent session cookie
          _create_and_set_session_cookie(@user)

          # Pull the saved return URL (fallback to root_path)
          return_to = session.delete(:return_to) || root_path
          render json: { status: 'success', redirect_url: return_to }
        end
      else
        format.html do
          flash.now[:alert] = message
          # Use safe template mapping instead of direct interpolation
          template = case @type
                     when 'webauthn' then 'verify_webauthn'
                     when 'sms' then 'verify_sms'
                     else 'verify_totp' # safe fallback for totp and unknown types
                     end
          render template
        end
        format.json { render json: { error: message }, status: :not_found }
      end
    end
  end

  # Strong parameters for WebAuthn verification
  # Match the exact camelCase keys sent by the WebAuthnJSON client
  def webauthn_verification_params
    params.require(:two_factor_authentication).permit(
      :id,
      :rawId,
      :type,
      :authenticatorAttachment,
      response: %i[clientDataJSON authenticatorData signature userHandle],
      clientExtensionResults: {}
    )
  end

  # Support WebAuthn with JSON endpoint for options
  # GET /two_factor_authentication/verification_options/:type
  def verification_options
    @type = params[:type]

    # Ensure authentication is in progress
    unless two_factor_auth_in_progress?
      respond_to do |format|
        format.html { redirect_to sign_in_path }
        format.json { render json: { error: 'Authentication required' }, status: :unauthorized }
        format.any { redirect_to sign_in_path }
      end
      return
    end

    if @type == 'webauthn'
      user_for_2fa = find_user_for_two_factor

      if user_for_2fa&.webauthn_credentials&.any?
        get_options = WebAuthn::Credential.options_for_get(
          allow: user_for_2fa.webauthn_credentials.pluck(:external_id)
        )
        store_challenge(:webauthn, get_options.challenge)

        # Use content negotiation - respond appropriately to the request format
        respond_to do |format|
          # When accessed via Ajax with JSON format, return JSON
          format.json { render json: get_options }
          # For form submission in HTML format, render the options as JSON with a special header
          format.html do
            # Check if it's an Ajax request looking for JSON
            if request.xhr?
              render json: get_options
            else
              # If it's a direct GET request, redirect back to verify method
              redirect_to verify_method_two_factor_authentication_path(type: 'webauthn')
            end
          end
        end
      else
        respond_to do |format|
          format.json { render json: { error: 'No security keys are registered for this account' }, status: :not_found }
          format.html { redirect_to sign_in_path, alert: 'No security key registered for this account.' }
        end
      end
    else
      respond_to do |format|
        format.json { render json: { error: 'Unsupported credential type' }, status: :bad_request }
        format.html { redirect_to sign_in_path, alert: 'Invalid verification method.' }
      end
    end
  end

  # GET /two_factor_authentication/credentials/webauthn/options
  def webauthn_creation_options
    # Get authenticator type from params (platform for biometric, cross-platform for security keys)
    authenticator_type = params[:authenticator_type]

    # Generate WebAuthn options - using update_column to bypass validations
    current_user.update_column(:webauthn_id, WebAuthn.generate_user_id) if current_user.webauthn_id.blank?

    # Create options based on authenticator type
    create_options = if authenticator_type == 'platform'
                       build_platform_create_options
                     else
                       build_cross_platform_create_options
                     end

    # Store challenge in session using the standardized helper
    store_challenge(
      :webauthn,
      create_options.challenge,
      { authenticator_type: authenticator_type }
    )

    render json: create_options
  end

  # Unified credential management methods

  # GET /two_factor_authentication/credentials/:type/new
  def new_credential
    @type = params[:type]

    case @type
    when 'webauthn'
      render 'webauthn_credentials/new'
    when 'totp'
      # Generate or retrieve validated secret - never use params directly
      @secret = get_validated_totp_secret(params[:secret])

      # Store the secret in the session
      store_challenge(
        :totp,
        nil, # TOTP doesn't need a challenge, just metadata
        { secret: @secret }
      )

      # Generate QR code with validated secret
      generate_totp_qr_code

      render 'totp_credentials/new'
    when 'sms'
      render 'sms_credentials/new'
    else
      redirect_to setup_two_factor_authentication_path,
                  alert: 'Invalid credential type'
    end
  end

  # POST /two_factor_authentication/credentials/:type
  def create_credential
    @type = params[:type]

    case @type
    when 'webauthn'
      # Process WebAuthn credential creation
      begin
        # Use require to ensure the nested hash exists and permit its contents
        # This nested hash contains the correct 'type' ('public-key')
        nested_params = params.expect(
          two_factor_authentication: [:id, :rawId, :type, :authenticatorAttachment,
                                      { response: [:clientDataJSON, :attestationObject, { transports: [] }],
                                        clientExtensionResults: {} }] # Permit all client extensions
        )

        # Log the permitted nested params being passed to from_create for debugging
        Rails.logger.debug { "[WEBAUTHN_DEBUG] Params passed to from_create: #{nested_params.inspect}" }
        Rails.logger.debug { "[WEBAUTHN_DEBUG] Params class: #{nested_params.class}" } # Should be ActionController::Parameters

        # The 'type' within nested_params should now correctly be 'public-key'
        webauthn_credential = WebAuthn::Credential.from_create(nested_params)

        # Verify challenge
        challenge_data = retrieve_challenge
        challenge = challenge_data[:challenge]

        webauthn_credential.verify(challenge)

        # Create credential in DB
        credential = current_user.webauthn_credentials.create!(
          external_id: webauthn_credential.id,
          nickname: params[:credential_nickname].presence || 'Security Key',
          public_key: webauthn_credential.public_key,
          sign_count: webauthn_credential.sign_count
          # authenticator_type: webauthn_credential.authenticator_attachment, # Get type from verified credential if needed/available
          # created_at: Time.current, # Let Rails handle timestamps
          # last_used_at: nil # Remove non-existent attribute
        )

        # Clear challenge
        clear_challenge

        Rails.logger.info("[2FA_CREDENTIAL] WebAuthn credential created for user #{current_user.id}, credential ID: #{credential.id}")

        # Response with JSON for AJAX handler
        render json: {
          status: 'ok',
          credential: {
            id: credential.id,
            nickname: credential.nickname,
            created_at: credential.created_at
          },
          redirect_url: credential_success_two_factor_authentication_path(type: 'webauthn')
        }
      rescue WebAuthn::Error => e
        Rails.logger.warn("[2FA_CREDENTIAL] WebAuthn credential verification failed for user #{current_user.id}: #{e.message}")
        render json: { error: "Verification failed: #{e.message}" }, status: :unprocessable_entity
      rescue StandardError => e
        Rails.logger.error("[2FA_CREDENTIAL] Error creating WebAuthn credential for user #{current_user.id}: #{e.message}")
        render json: { error: "Error creating credential: #{e.message}" }, status: :unprocessable_entity
      end
    when 'totp'
      # Get the secret from the session
      challenge_data = retrieve_challenge
      @secret = challenge_data[:metadata]&.dig(:secret) || params[:secret]

      # Directly verify the submitted code against the secret from the session/params
      # This is for the *initial* setup verification, before the credential is saved.
      totp = ROTP::TOTP.new(@secret)
      # Use default drift allowance (30s)
      if totp.verify(params[:code], drift_behind: 30, drift_ahead: 30)
        # Verification successful, proceed to create the credential
        respond_to do |format|
          # Create the credential
          credential = current_user.totp_credentials.create!(
            secret: @secret,
            nickname: params[:nickname].presence || 'Authenticator App',
            last_used_at: Time.current # Mark as used upon creation
          )
          Rails.logger.info("[2FA_CREDENTIAL] TOTP credential created for user #{current_user.id}, credential ID: #{credential.id}")

          clear_challenge # Clear the secret from the session

          format.html do
            redirect_to credential_success_two_factor_authentication_path(type: 'totp'),
                        notice: 'Authenticator app registered successfully'
          end
          format.turbo_stream do
            redirect_to credential_success_two_factor_authentication_path(type: 'totp'),
                        notice: 'Authenticator app registered successfully'
          end
        end
      else
        # Verification failed
        message = TwoFactorAuth::ERROR_MESSAGES[:invalid_code]
        Rails.logger.warn("[2FA_CREDENTIAL] TOTP credential setup verification failed for user #{current_user.id}: #{message}")
        log_verification_failure(current_user.id, :totp, 'Invalid code during setup') # Log the failure specifically for setup

        respond_to do |format|
          # Use flash.now for turbo_stream to display in the current response
          flash.now[:alert] = message

          format.html do
            # For regular HTML requests, redirect with flash
            flash[:alert] = message
            redirect_to new_credential_two_factor_authentication_path(type: 'totp', secret: @secret)
          end
          format.turbo_stream do
            # Regenerate the QR code before rendering the template
            # Ensure @secret is properly validated from params or session
            raw_secret = params[:secret] || challenge_data[:metadata]&.dig(:secret)
            @secret = validate_base32_secret(raw_secret) # Always validate before use
            
            if @secret
              @totp_uri = ROTP::TOTP.new(@secret, issuer: 'MatVulcan').provisioning_uri(current_user.email)
              @qr_code = RQRCode::QRCode.new(@totp_uri).as_svg(
                color: '000',
                shape_rendering: 'crispEdges',
                module_size: 4,
                standalone: true,
                use_path: true
              )
            else
              Rails.logger.error('[2FA_CREDENTIAL] Invalid or missing secret when regenerating QR code for failed setup.')
              # Generate a new valid secret if the old one is invalid
              @secret = ROTP::Base32.random
              @totp_uri = ROTP::TOTP.new(@secret, issuer: 'MatVulcan').provisioning_uri(current_user.email)
              @qr_code = RQRCode::QRCode.new(@totp_uri).as_svg(
                color: '000',
                shape_rendering: 'crispEdges',
                module_size: 4,
                standalone: true,
                use_path: true
              )
            end

            # For Turbo Stream, render the template with current flash
            render :create, status: :unprocessable_entity # Use appropriate status for validation failure
          end
        end
      end
    when 'sms'
      phone = params[:phone_number]

      # Check if phone is valid
      unless valid_phone_number?(phone)
        flash.now[:alert] = 'Invalid phone number format. Please try again.'
        return render 'sms_credentials/new'
      end

      # Create the credential
      @credential = current_user.sms_credentials.new(phone_number: phone)

      if @credential.save
        Rails.logger.info("[2FA_CREDENTIAL] SMS credential created (pending verification) for user #{current_user.id}, credential ID: #{@credential.id}")
        # Generate and send verification code
        if send_sms_verification_code(@credential)
          redirect_to verify_sms_credential_two_factor_authentication_path(id: @credential.id)
        else
          Rails.logger.error("[2FA_CREDENTIAL] Failed to send SMS verification code during setup for user #{current_user.id}, credential ID: #{@credential.id}")
          flash.now[:alert] = 'Could not send verification code'
          render 'sms_credentials/new'
        end
      else
        Rails.logger.warn("[2FA_CREDENTIAL] Failed to save SMS credential for user #{current_user.id}: #{@credential.errors.full_messages.join(', ')}")
        flash.now[:alert] = "Could not set up SMS authentication: #{@credential.errors.full_messages.join(', ')}"
        render 'sms_credentials/new'
      end
    else
      redirect_to setup_two_factor_authentication_path,
                  alert: 'Invalid credential type'
    end
  end

  # GET /two_factor_authentication/credentials/:type/success
  def credential_success
    @type = params[:type]

    case @type
    when 'webauthn'
      render 'webauthn_credentials/create_success'
    when 'totp'
      render 'totp_credentials/create_success'
    when 'sms'
      render 'sms_credentials/confirm_success'
    else
      redirect_to edit_profile_path
    end
  end

  # GET /two_factor_authentication/credentials/sms/:id/verify
  def verify_sms_credential
    @credential = current_user.sms_credentials.find_by(id: params[:id])

    unless @credential
      redirect_to new_credential_two_factor_authentication_path(type: 'sms'),
                  alert: 'SMS credential not found'
      return
    end

    render 'sms_credentials/verify'
  end

  # POST /two_factor_authentication/credentials/sms/:id/confirm
  def confirm_sms_credential
    @credential = current_user.sms_credentials.find_by(id: params[:id])

    unless @credential
      redirect_to new_credential_two_factor_authentication_path(type: 'sms'),
                  alert: 'SMS credential not found'
      return
    end

    code = params[:code]
    success, message = verify_sms_credential(code, @credential.id)

    if success
      redirect_to credential_success_two_factor_authentication_path(type: 'sms'),
                  notice: 'Phone number verified successfully'
    else
      flash.now[:alert] = message
      render 'sms_credentials/verify'
    end
  end

  # POST /two_factor_authentication/credentials/sms/:id/resend
  def resend_sms_code
    @credential = current_user.sms_credentials.find_by(id: params[:id])

    unless @credential
      redirect_to new_credential_two_factor_authentication_path(type: 'sms'),
                  alert: 'SMS credential not found'
      return
    end

    if send_sms_verification_code(@credential)
      redirect_to verify_sms_credential_two_factor_authentication_path(id: @credential.id),
                  notice: 'A new verification code has been sent'
    else
      redirect_to verify_sms_credential_two_factor_authentication_path(id: @credential.id),
                  alert: 'Could not send verification code'
    end
  end

  # DELETE /two_factor_authentication/credentials/:type/:id
  def destroy_credential
    @type = params[:type]

    case @type
    when 'webauthn'
      credential = current_user.webauthn_credentials.find_by(id: params[:id])
      credential_name = 'Security key'
    when 'totp'
      credential = current_user.totp_credentials.find_by(id: params[:id])
      credential_name = 'Authenticator app'
    when 'sms'
      credential = current_user.sms_credentials.find_by(id: params[:id])
      credential_name = 'SMS verification'
    else
      redirect_to edit_profile_path, alert: 'Invalid credential type'
      return
    end

    unless credential
      redirect_to edit_profile_path, alert: "#{credential_name} not found"
      return
    end

    credential_id_for_log = credential.id # Capture ID before destroy
    if credential.destroy
      Rails.logger.info("[2FA_CREDENTIAL] #{credential_name} (ID: #{credential_id_for_log}) removed successfully for user #{current_user.id}")
      redirect_to edit_profile_path, notice: "#{credential_name} removed successfully"
    else
      Rails.logger.error("[2FA_CREDENTIAL] Failed to remove #{credential_name.downcase} (ID: #{credential_id_for_log}) for user #{current_user.id}")
      redirect_to edit_profile_path, alert: "Failed to remove #{credential_name.downcase}"
    end
  end

  private

  # Process successful authentication
  def complete_authentication
    # Mark session as verified with standardized helper
    TwoFactorAuth.mark_verified(session)

    # Redirect to intended destination or default
    redirect_to session.delete(:return_to) || root_path
  end

  # Send an SMS verification code
  def send_sms_verification_code(credential = nil)
    # If no credential is provided, use current user's first SMS credential
    credential ||= current_user&.sms_credentials&.first
    return false unless credential

    # Generate code
    code = SecureRandom.random_number(10**6).to_s.rjust(6, '0')

    # Save to credential
    credential.update!(
      last_sent_at: Time.current,
      code_digest: User.digest(code),
      code_expires_at: 10.minutes.from_now
    )

    # Send SMS
    ::SmsService.send_message(
      credential.phone_number,
      "Your verification code is: #{code}"
    )

    # Store challenge data
    store_challenge(
      :sms,
      credential.code_digest,
      { credential_id: credential.id }
    )

    user_id = credential.user_id
    Rails.logger.info("[SMS] Sent verification code to user #{user_id}")
    true
  rescue StandardError => e
    Rails.logger.error("[SMS] Error: #{e.message}")
    flash.now[:alert] = 'Could not send verification code'
    false
  end

  # Verify a TOTP code
  def verify_totp_code(code)
    return false if code.blank?

    current_user.totp_credentials.each do |credential|
      totp = ROTP::TOTP.new(credential.secret)
      next unless totp.verify(code, drift_behind: 30, drift_ahead: 30)

      credential.update(last_used_at: Time.current)
      log_verification_success(current_user.id, :totp)
      return true
    end

    log_verification_failure(current_user.id, :totp, 'Invalid code')
    false
  end

  # Verify an SMS code
  def verify_sms_code(code)
    return false if code.blank?

    # Get credential ID from session
    challenge_data = retrieve_challenge
    credential_id = challenge_data[:metadata]&.dig(:credential_id)
    return false if credential_id.blank?

    # Find credential
    credential = current_user.sms_credentials.find_by(id: credential_id)
    return false if credential.nil?

    # Check expiration
    return false if credential.code_digest.blank? || credential.code_expires_at < Time.current

    # Verify code
    if BCrypt::Password.new(credential.code_digest).is_password?(code)
      clear_challenge
      log_verification_success(current_user.id, :sms)
      return true
    end

    log_verification_failure(current_user.id, :sms, 'Invalid code')
    false
  end

  # Check if two-factor authentication is in progress
  def two_factor_auth_in_progress?
    # Use the standardized session key from the TwoFactorAuth module
    session[TwoFactorAuth::SESSION_KEYS[:temp_user_id]].present?
  end

  # Find the user in the middle of two-factor authentication
  def find_user_for_two_factor
    # Use the standardized session key from the TwoFactorAuth module
    user_id = session[TwoFactorAuth::SESSION_KEYS[:temp_user_id]]
    User.find_by(id: user_id) if user_id
  end

  # WebAuthn credential creation options for platform authenticators (biometrics)
  def build_platform_create_options
    WebAuthn::Credential.options_for_create(
      user: {
        id: current_user.webauthn_id,
        name: current_user.email
      },
      exclude: current_user.webauthn_credentials.pluck(:external_id),
      authenticator_selection: {
        authenticator_attachment: 'platform',
        resident_key: 'preferred',
        user_verification: 'preferred'
      }
    )
  end

  # WebAuthn credential creation options for cross-platform authenticators (security keys)
  def build_cross_platform_create_options
    WebAuthn::Credential.options_for_create(
      user: {
        id: current_user.webauthn_id,
        name: current_user.email
      },
      exclude: current_user.webauthn_credentials.pluck(:external_id)
      # authenticator_selection: { # Omit entirely to allow any type with browser defaults
      #   # authenticator_attachment: 'cross-platform',
      #   # resident_key: 'discouraged',
      #   user_verification: 'preferred'
      # }
    )
  end

  # Helper method to validate phone numbers
  def valid_phone_number?(phone)
    # Basic validation (could use a gem like phonelib for better validation)
    phone.present? && phone.gsub(/\D/, '').length >= 10
  end

  # Validates TOTP secret to prevent XSS - uses ROTP's own validation
  def validate_base32_secret(secret)
    return nil if secret.blank?

    # Ensure secret is a string and contains only valid Base32 characters
    secret = secret.to_s.strip
    return nil unless secret.match?(/\A[A-Z2-7]+\z/)

    # Use ROTP to validate the secret format
    ROTP::Base32.decode(secret)
    secret
  rescue ArgumentError, ROTP::Base32::Base32Error
    nil
  end

  # Get a validated TOTP secret, never using params directly
  def get_validated_totp_secret(param_secret)
    # Use the secret from params if provided (for redirects after failed verification),
    # otherwise generate a new one. Always validate secret to prevent XSS.
    if param_secret.present?
      validated_secret = validate_base32_secret(param_secret)
      validated_secret || ROTP::Base32.random # Fallback if validation fails
    else
      ROTP::Base32.random
    end
  end

  # Generate QR code with validated secret only
  def generate_totp_qr_code
    # Only use the validated @secret instance variable
    @totp_uri = ROTP::TOTP.new(@secret, issuer: 'MatVulcan').provisioning_uri(current_user.email)
    @qr_code = RQRCode::QRCode.new(@totp_uri).as_svg(
      color: '000',
      shape_rendering: 'crispEdges',
      module_size: 4,
      standalone: true,
      use_path: true
    )
  end
end
