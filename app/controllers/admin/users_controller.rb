# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    # Define the mapping from expected demodulized names to full namespaced names.
    # These should match the actual class names under the Users module.
    VALID_USER_TYPES = {
      'Admin' => 'Users::Administrator',
      'Administrator' => 'Users::Administrator',
      'Evaluator' => 'Users::Evaluator',
      'Constituent' => 'Users::Constituent',
      'Vendor' => 'Users::Vendor',
      'Trainer' => 'Users::Trainer'
    }.freeze

    def index
      @users = User.includes(:role_capabilities)
                   .order(:type, :last_name, :first_name)
                   .to_a
    end

    def update_role
      # This logger is crucial to see what Rails gives us *before* any of our logic.
      Rails.logger.info "Admin::UsersController#update_role - Received raw params[:role]: #{params[:role].inspect} for user_id: #{params[:id]}"
      user = User.find(params[:id])
      raw_role_param = params[:role]

      namespaced_role = nil
      if raw_role_param.present? && raw_role_param.include?('::')
        # If it already looks namespaced, check if it's a valid known namespaced type
        namespaced_role = VALID_USER_TYPES.values.find { |v| v == raw_role_param }
      elsif raw_role_param.present?
        # If it's (presumably) demodulized, try to map it from its classified form
        namespaced_role = VALID_USER_TYPES[raw_role_param.classify]
      end

      if namespaced_role.blank?
        Rails.logger.warn "Admin::UsersController#update_role - Invalid or unmappable role received: #{raw_role_param.inspect} for user_id: #{user.id}. Valid types are: #{VALID_USER_TYPES.keys.join(', ')} (demodulized) or #{VALID_USER_TYPES.values.join(', ')} (namespaced)."
        render json: {
          success: false,
          message: "Invalid role specified: '#{raw_role_param}'. Please select a valid role."
        }, status: :unprocessable_entity
        return
      end

      Rails.logger.info "Admin::UsersController#update_role - Determined namespaced_role: #{namespaced_role.inspect} for user_id: #{user.id}"

      # Prevent Admin from changing their own role.
      # This method should ideally work with namespaced role strings.
      if user.prevent_self_role_update(current_user, namespaced_role)
        # Manually assign type and clear errors to handle STI validation crossover
        user.type
        user.type = namespaced_role

        # If the type actually changed, clear existing errors from the old type's context.
        # This is an attempt to prevent validations from the *previous* type from interfering.
        if user.type_changed? && user.type_was != user.type
          Rails.logger.info "Admin::UsersController#update_role - Type changed from #{user.type_was} to #{user.type}. Clearing errors."
          user.errors.clear
        end

        if user.save # This will use the new type (namespaced_role) for validation context
          update_user_capabilities(user, params[:capabilities]) if params[:capabilities].present?
          Rails.logger.info "Admin::UsersController#update_role - Successfully updated user_id: #{user.id} to type: #{user.type}"
          render json: {
            success: true,
            message: "#{user.full_name}'s role updated to #{namespaced_role.demodulize.titleize}."
          }
        else
          Rails.logger.error "Admin::UsersController#update_role - Failed to update user_id: #{user.id} to type #{namespaced_role}: #{user.errors.full_messages.join(', ')}"
          render json: {
            success: false,
            message: user.errors.full_messages.join(', ')
          }, status: :unprocessable_entity
        end
      else
        Rails.logger.warn "Admin::UsersController#update_role - Denied attempt by user_id: #{current_user.id} to change own role for user_id: #{user.id} to #{namespaced_role}"
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
