# frozen_string_literal: true

module Policies
  class BulkUpdateService < BaseService
    def initialize(policies_data:, current_user:)
      super()
      @policies_data = policies_data
      @current_user = current_user
    end

    def call
      Policy.transaction do
        update_policies
        success('Policies updated successfully.')
      end
    rescue ActiveRecord::RecordInvalid => e
      failure("Failed to update policies: #{e.record.errors.full_messages.join(', ')}")
    rescue ActiveRecord::RecordNotFound
      failure('Failed to update policies: Could not find one or more policies')
    end

    private

    attr_reader :policies_data, :current_user

    def update_policies
      normalized_policies_data.each do |policy_attrs|
        update_single_policy(policy_attrs)
      end
    end

    def update_single_policy(policy_attrs)
      policy = Policy.find(policy_attrs[:id])
      policy.updated_by = current_user
      raise ActiveRecord::RecordInvalid, policy unless policy.update(value: policy_attrs[:value])
    end

    def normalized_policies_data
      if policies_data.is_a?(Array)
        policies_data
      else
        policies_data.values
      end
    end
  end
end
