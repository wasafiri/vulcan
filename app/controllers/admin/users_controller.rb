# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    def index
      @users = User.includes(:role_capabilities)
                   .order(:type, :last_name, :first_name)
                   .to_a
    end

    def update_role
      Rails.logger.info "Admin::UsersController#update_role - Received params[:role]: #{params[:role].inspect}" # DEBUG LINE
      user = User.find(params[:id])
      new_role = params[:role]

      # Prevent Admin from changing their own role
      if user.prevent_self_role_update(current_user, new_role)
        if user.update(type: new_role)
          # Also update capabilities if they were sent
          update_user_capabilities(user, params[:capabilities]) if params[:capabilities].present?

          render json: {
            success: true,
            message: "#{user.full_name}'s role updated to #{new_role.sub('Users::', '').titleize}." # Adjusted for potentially namespaced role
          }
        else
          render json: {
            success: false,
            message: user.errors.full_messages.join(', ')
          }, status: :unprocessable_entity
        end
      else
        render json: {
          success: false,
          message: 'You cannot change your own role.'
        }, status: :forbidden
      end
    end

    def update_capabilities
      @user = User.find(params[:id])
      capability = params[:capability]
      enabled = ActiveModel::Type::Boolean.new.cast(params[:enabled])

      if enabled
        result = @user.add_capability(capability)
        Rails.logger.info "Adding capability #{capability} to user #{@user.id}: #{result}"

        if result.is_a?(RoleCapability)
          message = "Added #{capability.titleize} Capability"
          render json: { message: message, success: true }
        else
          error_message = result.errors.full_messages.join(', ') if result.respond_to?(:errors)
          Rails.logger.error "Failed to add capability: #{error_message}"
          render json: { message: error_message || 'Failed to add capability', success: false },
                 status: :unprocessable_entity
        end
      else
        result = @user.remove_capability(capability)
        Rails.logger.info "Removing capability #{capability} from user #{@user.id}: #{result}"

        if result
          message = "Removed #{capability.titleize} Capability"
          render json: { message: message, success: true }
        else
          render json: { message: 'Failed to remove capability', success: false }, status: :unprocessable_entity
        end
      end
    rescue StandardError => e
      Rails.logger.error "Error in update_capabilities: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: {
        success: false,
        message: e.message
      }, status: :unprocessable_entity
    end

    def show; end

    def edit; end

    def update; end

    def constituents
      @q = params[:q]
      scope = User.where(type: 'Constituent')
                  .joins(:applications)
                  .where(applications: { status: [Application.statuses[:rejected], Application.statuses[:archived]] })
                  .group('users.id')

      if @q.present?
        scope = scope.where("first_name ILIKE :q OR last_name ILIKE :q OR (first_name || ' ' || last_name) ILIKE :q",
                            q: "%#{@q}%")
      end

      @users = scope.order(:last_name)
    end

    def history
      @user = User.find(params[:id])
      @applications = @user.applications.order(application_date: :desc)
    end

    private

    def require_admin!
      redirect_to root_path, alert: 'Not authorized' unless current_user&.admin?
    end

    def user_params
      params.require(:user).permit(:type, capabilities: [])
    end
  end
end
