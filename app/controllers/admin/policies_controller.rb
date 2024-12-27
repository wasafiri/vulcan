class Admin::PoliciesController < ApplicationController
  before_action :require_admin!
  before_action :set_policies, only: [ :edit, :update ]

  def edit
  end

  def update
    Policy.transaction do
      params[:policies].each do |id, policy_params|
        policy = Policy.find(policy_params[:id])
        policy.update!(value: policy_params[:value])
      end
    end
    redirect_to edit_admin_policies_path, notice: "Policies updated successfully."
  rescue ActiveRecord::RecordInvalid
    redirect_to edit_admin_policies_path, alert: "Failed to update policies."
  end

  private

  def set_policies
    @policies = Policy.all
  end
end
