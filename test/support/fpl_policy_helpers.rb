# frozen_string_literal: true

module FplPolicyHelpers
  def setup_fpl_policies
    # Stub the log_change method to avoid validation errors in test
    Policy.class_eval do
      def log_change
        # No-op in test environment to bypass the user requirement
      end
    end

    # Set up 2024 FPL values for testing purposes (matching db/seeds.rb)
    Policy.find_or_create_by(key: 'fpl_1_person').update(value: 15_650)
    Policy.find_or_create_by(key: 'fpl_2_person').update(value: 21_150)
    Policy.find_or_create_by(key: 'fpl_3_person').update(value: 26_650)
    Policy.find_or_create_by(key: 'fpl_4_person').update(value: 32_150)
    Policy.find_or_create_by(key: 'fpl_5_person').update(value: 37_650)
    Policy.find_or_create_by(key: 'fpl_6_person').update(value: 43_150)
    Policy.find_or_create_by(key: 'fpl_7_person').update(value: 48_650)
    Policy.find_or_create_by(key: 'fpl_8_person').update(value: 54_150)
    Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)
  end
end
