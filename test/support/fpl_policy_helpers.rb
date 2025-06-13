module FplPolicyHelpers
  def setup_fpl_policies
    # Stub the log_change method to avoid validation errors in test
    Policy.class_eval do
      def log_change
        # No-op in test environment to bypass the user requirement
      end
    end

    # Set up standard FPL values for testing purposes
    Policy.find_or_create_by(key: 'fpl_1_person').update(value: 15_000)
    Policy.find_or_create_by(key: 'fpl_2_person').update(value: 20_000)
    Policy.find_or_create_by(key: 'fpl_3_person').update(value: 25_000)
    Policy.find_or_create_by(key: 'fpl_4_person').update(value: 30_000)
    Policy.find_or_create_by(key: 'fpl_5_person').update(value: 35_000)
    Policy.find_or_create_by(key: 'fpl_6_person').update(value: 40_000)
    Policy.find_or_create_by(key: 'fpl_7_person').update(value: 45_000)
    Policy.find_or_create_by(key: 'fpl_8_person').update(value: 50_000)
    Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)
  end
end 