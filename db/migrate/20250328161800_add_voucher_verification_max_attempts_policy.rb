# frozen_string_literal: true

class AddVoucherVerificationMaxAttemptsPolicy < ActiveRecord::Migration[7.0]
  def up
    # Add policy for maximum verification attempts
    policy = Policy.find_or_initialize_by(key: 'voucher_verification_max_attempts')
    policy.value = 3 # Default to 3 attempts
    policy.save!
  end

  def down
    Policy.where(key: 'voucher_verification_max_attempts').destroy_all
  end
end
