class Admin::UsersController < ApplicationController
  def index
    @users = User.all
  end

  def update_role
    user = User.find(params[:id])
    new_role = params[:role]

    # Prevent Admin from changing their own role
    if user.prevent_self_role_update(current_user, new_role)
      if user.update(type: new_role)
        render json: { success: true, message: "#{user.full_name}'s role updated to #{new_role.titleize}." }
      else
        render json: { success: false, message: user.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    else
      render json: { success: false, message: "You cannot change your own role." }, status: :forbidden
    end
  end

  def show
  end

  def edit
  end

  def update
  end
end
