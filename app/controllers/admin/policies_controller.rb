class Admin::PoliciesController < ApplicationController
  include Pagy::Backend
  before_action :require_admin!
  before_action :set_policy, only: [ :show, :edit ]

  def index
    @policies = Policy.all.order(:key)
    @recent_changes = PolicyChange.includes(:policy, :user)
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
    Policy.transaction do
      params[:policies].each do |_key, policy_params|
        policy = Policy.find(policy_params[:id])
        policy.updated_by = current_user

        unless policy.update(value: policy_params[:value])
          raise ActiveRecord::RecordInvalid.new(policy)
        end
      end

      redirect_to admin_policies_path, notice: "Policies updated successfully."
    end
  rescue ActiveRecord::RecordInvalid => e
    flash[:alert] = "Failed to update policies: #{e.record.errors.full_messages.join(', ')}"
    redirect_to admin_policies_path
  rescue ActiveRecord::RecordNotFound => e
    flash[:alert] = "Failed to update policies: Could not find one or more policies"
    redirect_to admin_policies_path
  end

  private

  def set_policy
    @policy = Policy.find(params[:id])
  end

  def set_policies
    @policies = Policy.all
  end

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorized"
    end
  end

  def policy_params
    params.require(:policies).permit!
  end

  def create_policy_params
    params.require(:policy).permit(:key, :value)
  end
end
