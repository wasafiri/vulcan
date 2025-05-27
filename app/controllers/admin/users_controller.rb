# frozen_string_literal: true

module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    def index
      @q = params[:q]
      @role_filter = params[:role] # e.g., "guardian" or "dependent" from paper app form
      @frame_id = params[:turbo_frame_id] # e.g., "guardian_search_results"

      # Base query with ordering
      base_query = User.order(:type, :last_name, :first_name)

      if @q.present?
        query_term = "%#{@q.downcase}%"
        base_query = base_query.where(
          'LOWER(first_name) ILIKE :q OR LOWER(last_name) ILIKE :q OR LOWER(email) ILIKE :q', q: query_term
        )
      elsif turbo_frame_request_id&.end_with?('_search_results')
        # If no query, and it's a turbo frame request for search, return empty results
        base_query = base_query.none
      end

      # Fetch limited results for dropdown
      @users = base_query.limit(10).to_a

      respond_to do |format|
        format.html do
          if turbo_frame_request_id == "#{@role_filter}_search_results" || @frame_id == "#{@role_filter}_search_results"
            render partial: 'admin/users/user_search_results_list', locals: { users: @users, role: @role_filter }
          elsif @q.blank?
            # For full page load without query, re-query without limit
            @users = User.order(:type, :last_name, :first_name).to_a

            # Only get the counts that the index view needs to avoid N+1 queries
            constituent_ids = @users.select { |user| user.is_a?(Users::Constituent) }.map(&:id)
            if constituent_ids.any?
              constituent_records = {}

              # Get counts directly rather than loading associations
              dependents_counts = GuardianRelationship.where(guardian_id: constituent_ids)
                                                      .group(:guardian_id)
                                                      .count

              has_guardian = GuardianRelationship.where(dependent_id: constituent_ids)
                                                 .distinct
                                                 .pluck(:dependent_id)

              # Get the actual users
              Users::Constituent.where(id: constituent_ids).find_each do |user|
                # Store the counts as attributes on the user
                user.instance_variable_set(:@dependents_count, dependents_counts[user.id] || 0)
                user.instance_variable_set(:@has_guardian, has_guardian.include?(user.id))

                # Add helper methods to access this data
                class << user
                  def dependents_count
                    @dependents_count || 0
                  end

                  def has_guardian?
                    @has_guardian || false
                  end
                end

                constituent_records[user.id] = user
              end

              # Replace the users in the array with our enhanced users
              @users.each_with_index do |user, index|
                @users[index] = constituent_records[user.id] if user.is_a?(Users::Constituent) && constituent_records[user.id]
              end
            end
          end
        end
        format.json { render json: @users.as_json(only: %i[id first_name last_name email]) }
      end
    end

    def show
      # Fetch the user without eager loading problematic associations
      @user = User.find(params[:id])

      # Only enhance the data if this is a Constituent user
      return unless @user.is_a?(Users::Constituent)

      # Get relationship info directly without using eager loading
      dependent_rels = GuardianRelationship.where(guardian_id: @user.id)
                                           .select(:id, :guardian_id, :dependent_id, :relationship_type)
                                           .to_a

      guardian_rels = GuardianRelationship.where(dependent_id: @user.id)
                                          .select(:id, :guardian_id, :dependent_id, :relationship_type)
                                          .to_a

      # Manually fetch the related users to avoid eager loading warnings
      all_user_ids = dependent_rels.map(&:dependent_id) + guardian_rels.map(&:guardian_id)

      if all_user_ids.any?
        related_users = User.where(id: all_user_ids).index_by(&:id)

        # Attach the dependent users to dependent relationships
        dependent_rels.each do |rel|
          # Define a method to get the dependent user
          rel.define_singleton_method(:dependent_user) do
            related_users[rel.dependent_id]
          end
        end

        # Attach the guardian users to guardian relationships
        guardian_rels.each do |rel|
          # Define a method to get the guardian user
          rel.define_singleton_method(:guardian_user) do
            related_users[rel.guardian_id]
          end
        end
      end

      # Set instance variables for the view
      @dependents_count = dependent_rels.size
      @has_guardian = guardian_rels.any?
      @guardian_relationships = guardian_rels
      @dependent_relationships = dependent_rels

      # Add helper methods to this specific user object
      @user.instance_variable_set(:@dependents_count, @dependents_count)
      @user.instance_variable_set(:@has_guardian, @has_guardian)

      # Define the helper methods on the instance
      class << @user
        def dependents_count
          @dependents_count || 0
        end

        def has_guardian?
          @has_guardian || false
        end
      end
    end

    def edit; end

    # Create action for creating a new guardian from the paper application form
    def create
      @user = Users::Constituent.new(user_create_params)
      @user.password = @user.password_confirmation = SecureRandom.hex(8)
      @user.force_password_change = true
      @user.verified = true

      # Check for potential duplicates based on Name + DOB
      @user.needs_duplicate_review = true if potential_duplicate_found?(@user)

      if @user.save
        render json: {
          success: true,
          user: @user.as_json(only: %i[id first_name last_name email phone
                                       physical_address_1 physical_address_2 city state zip_code])
        }
      else
        render json: {
          success: false,
          errors: @user.errors.full_messages
        }, status: :unprocessable_entity
      end
    end

    # New dedicated search endpoint for user search
    def search
      @q = params[:q]
      @role_filter = params[:role] # e.g., "guardian" or "dependent" from paper app form
      @frame_id = "#{@role_filter}_search_results"

      base_query = User.order(:last_name, :first_name)

      if @q.present?
        query_term = "%#{@q.downcase}%"
        base_query = base_query.where(
          'LOWER(first_name) ILIKE :q OR LOWER(last_name) ILIKE :q OR LOWER(email) ILIKE :q', q: query_term
        )
      else
        # If no query, return empty results
        base_query = base_query.none
      end

      # Get basic users without eager loading
      @users = base_query.limit(10).to_a # Limit results for search dropdown

      # Selectively optimize for Users::Constituent models
      constituent_ids = @users.select { |user| user.is_a?(Users::Constituent) }.map(&:id)
      if constituent_ids.any?
        constituent_records = {}

        # Get counts directly rather than loading associations
        dependents_counts = GuardianRelationship.where(guardian_id: constituent_ids)
                                                .group(:guardian_id)
                                                .count

        has_guardian = GuardianRelationship.where(dependent_id: constituent_ids)
                                           .distinct
                                           .pluck(:dependent_id)

        # Get the actual users and enhance them
        Users::Constituent.where(id: constituent_ids).find_each do |user|
          user.instance_variable_set(:@dependents_count, dependents_counts[user.id] || 0)
          user.instance_variable_set(:@has_guardian, has_guardian.include?(user.id))

          # Add helper methods to access the data
          class << user
            def dependents_count
              @dependents_count || 0
            end

            def has_guardian?
              @has_guardian || false
            end
          end

          constituent_records[user.id] = user
        end

        # Replace the users in the array with our enhanced users
        @users.each_with_index do |user, index|
          @users[index] = constituent_records[user.id] if user.is_a?(Users::Constituent) && constituent_records[user.id]
        end
      end

      render partial: 'admin/users/user_search_results_list', locals: { users: @users, role: @role_filter }
    end

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
        if user.type == namespaced_role
          # Type is not actually changing, just ensure capabilities are updated if sent
          update_user_capabilities(user, params[:capabilities]) if params[:capabilities].present?
          Rails.logger.info "Admin::UsersController#update_role - Type #{user.type} not changed. Capabilities updated if provided."
          render json: {
            success: true,
            message: "#{user.full_name}'s role is already #{namespaced_role.demodulize.titleize}."
          }
        else
          # Type is changing
          new_klass = namespaced_role.safe_constantize
          if new_klass.blank? || !new_klass.ancestors.include?(User)
            Rails.logger.error "Admin::UsersController#update_role - Invalid target class for STI: #{namespaced_role}"
            render json: { success: false, message: 'Invalid target role class.' }, status: :unprocessable_entity
            return
          end

          # Convert the user to the new type. `becomes` returns a new object of the target class.
          converted_user = user.becomes(new_klass)

          # Explicitly null out type-specific fields when changing from one type to another
          # to avoid validation crossover issues
          if user.type_was == 'Users::Vendor' && !converted_user.is_a?(Users::Vendor)
            Rails.logger.info "Admin::UsersController#update_role - Nullifying vendor-specific fields for user_id: #{user.id}"
            converted_user.business_name = nil
            converted_user.business_tax_id = nil
            converted_user.terms_accepted_at = nil
            converted_user.w9_status = nil # Reset enum to default if it exists
            # Don't purge attachments in the controller - that should be a separate, deliberate action
          end
          # Add similar blocks for other types if they have type-specific fields

          # Attributes are copied. Now, when we save converted_user,
          # only validations for the new_klass (and User base) should run.

          if converted_user.save # Save the new, converted instance
            update_user_capabilities(converted_user, params[:capabilities]) if params[:capabilities].present?
            Rails.logger.info "Admin::UsersController#update_role - Successfully updated user_id: #{converted_user.id} to type: #{converted_user.type}"
            render json: {
              success: true,
              message: "#{converted_user.full_name}'s role updated to #{converted_user.type.demodulize.titleize}."
            }
          else
            Rails.logger.error "Admin::UsersController#update_role - Failed to save converted_user_id: #{user.id} (original id) as type #{namespaced_role}: #{converted_user.errors.full_messages.join(', ')}"
            render json: {
              success: false,
              message: converted_user.errors.full_messages.join(', ')
            }, status: :unprocessable_entity
          end
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
      params.expect(user: [:type, { capabilities: [] }])
    end

    # Handles updating capabilities for a user
    # Used by update_role to ensure capabilities are maintained when changing user types
    def update_user_capabilities(user, capabilities)
      return if capabilities.blank?

      # Clear existing capabilities first
      user.role_capabilities.destroy_all

      # Add each new capability
      capabilities.each do |capability|
        user.add_capability(capability)
      end
    end

    # Permits parameters for creating a constituent user
    # Called in the create action
    def user_create_params
      # When called from the admin UI (normal user create form), parameters come wrapped in :user
      # When called from the paper application form, parameters come directly (unwrapped)
      if params.key?(:user)
        params.expect(
          user: %i[first_name last_name email phone
                   physical_address_1 physical_address_2
                   city state zip_code date_of_birth
                   communication_preference locale]
        )
      else
        # Handle direct params from paper application form's guardian_attributes
        params.permit(
          :first_name, :last_name, :email, :phone,
          :physical_address_1, :physical_address_2,
          :city, :state, :zip_code, :date_of_birth,
          :communication_preference, :locale
        )
      end
    end

    # Checks for possible duplicate users based on name and date of birth
    # Called in the create action to flag potential duplicates for review
    def potential_duplicate_found?(user)
      return false unless user.first_name.present? && user.last_name.present? && user.date_of_birth.present?

      User.exists?(['LOWER(first_name) = ? AND LOWER(last_name) = ? AND date_of_birth = ?',
                    user.first_name.downcase,
                    user.last_name.downcase,
                    user.date_of_birth])
    end
  end
end
