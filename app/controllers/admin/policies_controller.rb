class Admin::PoliciesController < ApplicationController
  include Pagy::Backend
  before_action :require_admin!
  before_action :set_policies, only: [ :edit, :update ]

  def edit
    @policies = Policy.all
    @recent_changes = PolicyChange.includes(:policy, :user)
                                .order(created_at: :desc)
                                .limit(10)
  end

  def update
    Policy.transaction do
      params[:policies].each do |id, policy_params|
        policy = Policy.find(policy_params[:id])
        policy.updated_by = current_user
        policy.update!(value: policy_params[:value])
      end
      redirect_to edit_admin_policies_path, notice: "Policies updated successfully."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_admin_policies_path, alert: "Failed to update policies: #{e.message}"
  end

  def changes
    @pagy, @policy_changes = pagy(
      PolicyChange.includes(:policy, :user).order(created_at: :desc),
      items: 25
    )
  end

  private

  def set_policies
    @policies = Policy.all
  end
end
