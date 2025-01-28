class Admin::UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def index
    @users = User.includes(:role_capabilities)
      .order(:type, :last_name, :first_name)
  end

  def update_role
    user = User.find(params[:id])
    new_role = params[:role]

    # Prevent Admin from changing their own role
    if user.prevent_self_role_update(current_user, new_role)
      if user.update(type: new_role)
        # Also update capabilities if they were sent
        if params[:capabilities].present?
          update_user_capabilities(user, params[:capabilities])
        end

        render json: {
          success: true,
          message: "#{user.full_name}'s role updated to #{new_role.titleize}."
        }
      else
        render json: {
          success: false,
          message: user.errors.full_messages.join(", ")
        }, status: :unprocessable_entity
      end
    else
      render json: {
        success: false,
        message: "You cannot change your own role."
      }, status: :forbidden
    end
  end

  def update_capabilities
    user = User.find(params[:id])
    capability = params[:capability]

    if params[:enabled].to_s == "true"
      if user.add_capability(capability)
        render json: {
          success: true,
          message: "Added #{capability.titleize} capability to #{user.full_name}"
        }
      else
        render json: {
          success: false,
          message: "Could not add capability: #{user.errors.full_messages.join(', ')}"
        }, status: :unprocessable_entity
      end
    else
      if user.remove_capability(capability)
        render json: {
          success: true,
          message: "Removed #{capability.titleize} capability from #{user.full_name}"
        }
      else
        render json: {
          success: false,
          message: "Could not remove capability: #{user.errors.full_messages.join(', ')}"
        }, status: :unprocessable_entity
      end
    end
  rescue => e
    render json: {
      success: false,
      message: e.message
    }, status: :unprocessable_entity
  end

  def show
  end

  def edit
  end

  def update
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Not authorized"
    end
  end

  private

  def update_user_capabilities(user, capabilities)
    # Remove capabilities that aren't in the new list
    user.role_capabilities.where.not(capability: capabilities).destroy_all

    # Add new capabilities
    capabilities.each do |capability|
      user.add_capability(capability) unless user.has_capability?(capability)
    end
  end

  def user_params
    params.require(:user).permit(:type, capabilities: [])
  end
end
