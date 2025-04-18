# frozen_string_literal: true

module Admin
  class PoliciesController < Admin::BaseController
    before_action :set_policy, only: %i[show edit update]

    def index
      @policies = Policy.all.order(:key)
      @recent_changes = PolicyChange.includes(:policy, :user)
                                    .order(created_at: :desc)
                                    .limit(10)
    end

    def show
      # The policy is already set by the before_action
      @recent_changes = PolicyChange.where(policy: @policy)
                                    .includes(:user)
                                    .order(created_at: :desc)
                                    .limit(10)
    end

    def edit
      @policies = Policy.all
      @recent_changes = PolicyChange.includes(:policy, :user)
                                    .order(created_at: :desc)
                                    .limit(10)
    end

    def changes
      @pagy, @policy_changes = pagy(
        PolicyChange.includes(:policy, :user)
          .order(created_at: :desc),
        items: 25
      )
    end

    def create
      @policy = Policy.new(create_policy_params)
      @policy.updated_by = current_user

      if @policy.save
        redirect_to admin_policies_path, notice: "Policy '#{@policy.key}' created successfully."
      else
        flash[:alert] = "Failed to create policy: #{@policy.errors.full_messages.join(', ')}"
        redirect_to admin_policies_path
      end
    end

    def update
      # Single policy update
      @policy.updated_by = current_user
      if @policy.update(value: params[:policy][:value])
        redirect_to admin_policies_path, notice: "Policy '#{@policy.key}' updated successfully."
      else
        @policies = Policy.all
        @recent_changes = PolicyChange.includes(:policy, :user)
                                      .order(created_at: :desc)
                                      .limit(10)
        flash.now[:alert] = "Failed to update policy: #{@policy.errors.full_messages.join(', ')}"
        render :edit, status: :unprocessable_entity
      end
    end

    def bulk_update
      @policies = Policy.all
      Policy.transaction do
        policies_data = policy_params

        if policies_data.is_a?(Array)
          policies_data.each do |policy_attrs|
            policy = Policy.find(policy_attrs[:id])
            policy.updated_by = current_user
            raise ::ActiveRecord::RecordInvalid, policy unless policy.update(value: policy_attrs[:value])
          end
        else
          policies_data.each_value do |policy_attrs|
            policy = Policy.find(policy_attrs[:id])
            policy.updated_by = current_user
            raise ::ActiveRecord::RecordInvalid, policy unless policy.update(value: policy_attrs[:value])
          end
        end

        redirect_to admin_policies_path, notice: 'Policies updated successfully.'
      end
    rescue ::ActiveRecord::RecordInvalid => e
      flash[:alert] = "Failed to update policies: #{e.record.errors.full_messages.join(', ')}"
      redirect_to admin_policies_path
    rescue ::ActiveRecord::RecordNotFound
      flash[:alert] = 'Failed to update policies: Could not find one or more policies'
      redirect_to admin_policies_path
    end

    private

    def set_policy
      @policy = Policy.find(params[:id])
    end

    def set_policies
      @policies = Policy.all
    end

    def policy_params
      if params[:policies].is_a?(Array)
        # New array format
        params.permit(policies: %i[id value])[:policies]
      else
        # Legacy hash format
        permitted_policies = {}
        params.require(:policies).each do |id, attrs|
          permitted_policies[id] = { id: attrs[:id], value: attrs[:value] }
        end
        permitted_policies
      end
    end

    def create_policy_params
      params.require(:policy).permit(:key, :value)
    end
  end
end
