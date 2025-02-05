class UsersController < ApplicationController
  before_action :authenticate_user!
  helper_method :after_update_path  # Add this line to make the method available to views

  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(user_params)
      flash[:notice] = "Profile successfully updated"
      redirect_to after_update_path(@user)  # Add @user as argument
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email)
  end

  def after_update_path(user)
    case user
    when Admin then admin_applications_path
    when Constituent then constituent_dashboard_path
    when Evaluator then evaluators_dashboard_path
    when Vendor then vendor_dashboard_path
    else root_path
    end
  end
end
