# frozen_string_literal: true

module Admin
  module PoliciesHelper
    def format_policy_value(key, value)
      case key
      when /^fpl_\d+_person$/
        number_to_currency(value)
      when 'fpl_modifier_percentage'
        "#{value}%"
      else
        value.to_s
      end
    end

    def policy_description(key)
      case key
      when 'max_training_sessions'
        'Maximum number of training sessions allowed per constituent'
      when 'waiting_period_years'
        'Number of years required between applications'
      when 'fpl_modifier_percentage'
        'Percentage multiplier applied to Federal Poverty Level for eligibility threshold'
      else
        'No description available'
      end
    end
  end
end
