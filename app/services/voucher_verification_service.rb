# frozen_string_literal: true

# Service to handle voucher date of birth verification
class VoucherVerificationService
  attr_reader :voucher, :submitted_dob_str, :session, :max_attempts

  def initialize(voucher, submitted_dob_str, session)
    @voucher = voucher
    @submitted_dob_str = submitted_dob_str
    @session = session
    @max_attempts = Policy.get('voucher_verification_max_attempts') || 3
  end

  def verify
    # Parse the submitted DOB
    return failed_result(:invalid_format) unless valid_dob_format?

    # Check if the DOB matches
    if dobs_match?
      handle_successful_verification
    else
      handle_failed_verification
    end
  end

  private

  def valid_dob_format?
    !parsed_dob.nil?
  end

  def parsed_dob
    @parsed_dob ||= begin
      Date.parse(submitted_dob_str)
    rescue StandardError
      nil
    end
  end

  def dobs_match?
    constituent = voucher.application.user
    constituent.date_of_birth && parsed_dob == constituent.date_of_birth
  end

  def handle_successful_verification
    # Reset attempts counter
    reset_verification_attempts

    # Mark this voucher as verified
    verified_vouchers << voucher.id

    VerificationResult.new(
      success: true,
      message_key: 'dob_verification_success'
    )
  end

  def handle_failed_verification
    # Increment failed attempts counter
    increment_verification_attempts

    current_attempts = verification_attempts

    if current_attempts >= max_attempts
      VerificationResult.new(
        success: false,
        message_key: 'dob_verification_too_many_attempts',
        attempts_left: 0
      )
    else
      attempts_left = max_attempts - current_attempts
      VerificationResult.new(
        success: false,
        message_key: 'dob_verification_failed',
        attempts_left: attempts_left
      )
    end
  end

  def verification_attempts
    verification_attempts_hash[voucher.id.to_s] || 0
  end

  def increment_verification_attempts
    verification_attempts_hash[voucher.id.to_s] = verification_attempts + 1
  end

  def reset_verification_attempts
    verification_attempts_hash[voucher.id.to_s] = 0
  end

  def verification_attempts_hash
    session[:voucher_verification_attempts] ||= {}
  end

  def verified_vouchers
    session[:verified_vouchers] ||= []
  end

  # Simple value object to represent verification result
  class VerificationResult
    attr_reader :success, :message_key, :attempts_left

    def initialize(success:, message_key:, attempts_left: nil)
      @success = success
      @message_key = message_key
      @attempts_left = attempts_left
    end

    def success?
      @success
    end
  end
end
