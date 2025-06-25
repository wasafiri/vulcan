# frozen_string_literal: true

# Service for calculating income thresholds based on Federal Poverty Level (FPL) guidelines
class IncomeThresholdCalculationService < BaseService
  def self.call(household_size)
    new(household_size).call
  end

  def initialize(household_size)
    super()
    @household_size = household_size.to_i
  end

  def call
    base_fpl = Policy.get("fpl_#{[@household_size, 8].min}_person").to_i
    modifier = Policy.get('fpl_modifier_percentage').to_i
    threshold = base_fpl * (modifier / 100.0)

    success('Threshold calculated successfully', {
      household_size: @household_size,
      base_fpl: base_fpl,
      modifier: modifier,
      threshold: threshold
    })
  rescue StandardError => e
    log_error(e, "Failed to calculate income threshold for household size #{@household_size}")
    failure("Unable to calculate income threshold: #{e.message}")
  end
end
