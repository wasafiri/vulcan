module ConstituentPortal
  class ApplicationsController < ApplicationController
    before_action :authenticate_user!, except: [ :fpl_thresholds ]
    before_action :require_constituent!, except: [ :fpl_thresholds ]
    before_action :set_application, only: [ :show, :edit, :update, :verify, :submit ]
    before_action :ensure_editable, only: [ :edit, :update ]
    before_action :cast_boolean_params, only: [ :create, :update ]

    def index
      @applications = current_user.applications.order(created_at: :desc)
    end

    def show
    end

    def new
      @application = current_user.applications.new
    end

    def create
      @application = current_user.applications.new(filtered_application_params)

      # Set initial application attributes
      @application.status = params[:submit_application] ? :in_progress : :draft
      @application.application_date = Time.current
      @application.submission_method = :online

      # Set application_type to "new" by default if not specified
      @application.application_type ||= :new

      # Handle medical provider info - check both possible locations
      if params[:medical_provider].present?
        @application.assign_attributes(
          medical_provider_name: params[:medical_provider][:name],
          medical_provider_phone: params[:medical_provider][:phone],
          medical_provider_fax: params[:medical_provider][:fax],
          medical_provider_email: params[:medical_provider][:email]
        )
      elsif params.dig(:application, :medical_provider).present?
        medical_provider_attrs = params[:application][:medical_provider].permit(
          :name, :phone, :fax, :email
        )
        @application.assign_attributes(
          medical_provider_name: medical_provider_attrs[:name],
          medical_provider_phone: medical_provider_attrs[:phone],
          medical_provider_fax: medical_provider_attrs[:fax],
          medical_provider_email: medical_provider_attrs[:email]
        )
      end

      # Extract user attributes
      user_attrs = {
        is_guardian: params[:application][:is_guardian] == "1" || params[:application][:is_guardian] == true,
        guardian_relationship: params[:application][:guardian_relationship],
        hearing_disability: params[:application][:hearing_disability] == "1" || params[:application][:hearing_disability] == true,
        vision_disability: params[:application][:vision_disability] == "1" || params[:application][:vision_disability] == true,
        speech_disability: params[:application][:speech_disability] == "1" || params[:application][:speech_disability] == true,
        mobility_disability: params[:application][:mobility_disability] == "1" || params[:application][:mobility_disability] == true,
        cognition_disability: params[:application][:cognition_disability] == "1" || params[:application][:cognition_disability] == true
      }

      # Debug logging for guardian attributes
      Rails.logger.debug "Guardian checkbox value: #{params[:application][:is_guardian].inspect}"
      Rails.logger.debug "Guardian relationship value: #{params[:application][:guardian_relationship].inspect}"

      Rails.logger.debug "Application attributes before save: #{@application.attributes.inspect}"
      Rails.logger.debug "Medical provider params: #{params[:medical_provider].inspect}"
      Rails.logger.debug "Application valid? #{@application.valid?}"
      Rails.logger.debug "Application errors: #{@application.errors.full_messages}" if @application.invalid?

      success = ActiveRecord::Base.transaction do
        if @application.valid? && update_user_attributes(user_attrs)
          @application.save!
          true
        else
          @application.errors.merge!(current_user.errors)
          false
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "Transaction failed: #{e.message}"
        false
      end

      if success
        # Log guardian relationship if applicable
        if current_user.is_guardian? && @application.persisted?
          Event.create!(
            user: current_user,
            action: "guardian_application_submitted",
            metadata: {
              application_id: @application.id,
              guardian_relationship: current_user.guardian_relationship,
              timestamp: Time.current.iso8601
            }
          )
        end

        if params[:submit_application]
          redirect_to constituent_portal_application_path(@application),
            notice: "Application submitted successfully!"
        else
          redirect_to constituent_portal_application_path(@application),
            notice: "Application saved as draft."
        end
      else
        # Create a medical_provider object for the form when validation fails
        @medical_provider = OpenStruct.new(
          name: params.dig(:medical_provider, :name) || params.dig(:application, :medical_provider, :name),
          phone: params.dig(:medical_provider, :phone) || params.dig(:application, :medical_provider, :phone),
          fax: params.dig(:medical_provider, :fax) || params.dig(:application, :medical_provider, :fax),
          email: params.dig(:medical_provider, :email) || params.dig(:application, :medical_provider, :email)
        )
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      # Track original status for change detection
      original_status = @application.status

      # Clean annual income and prepare application attributes
      application_attrs = filtered_application_params.merge(
        annual_income: params[:application][:annual_income]&.gsub(/[^\d.]/, "")
      )

      # Handle medical provider attributes
      if params[:application][:medical_provider].present?
        medical_provider_attrs = params[:application][:medical_provider].permit(
          :name, :phone, :fax, :email
        )

        # Debug logging for medical provider attributes
        Rails.logger.debug "Medical provider params: #{params[:application][:medical_provider].inspect}"
        Rails.logger.debug "Medical provider attrs after permit: #{medical_provider_attrs.inspect}"

        # Directly assign medical provider attributes to the application
        @application.medical_provider_name = medical_provider_attrs[:name]
        @application.medical_provider_phone = medical_provider_attrs[:phone]
        @application.medical_provider_fax = medical_provider_attrs[:fax]
        @application.medical_provider_email = medical_provider_attrs[:email]

        # Also merge into application_attrs for completeness
        application_attrs.merge!(
          medical_provider_name: medical_provider_attrs[:name],
          medical_provider_phone: medical_provider_attrs[:phone],
          medical_provider_fax: medical_provider_attrs[:fax],
          medical_provider_email: medical_provider_attrs[:email]
        )
      end

      # Extract user attributes
      user_attrs = {
        is_guardian: params[:application][:is_guardian] == "1" || params[:application][:is_guardian] == true,
        guardian_relationship: params[:application][:guardian_relationship],
        hearing_disability: params[:application][:hearing_disability] == "1" || params[:application][:hearing_disability] == true,
        vision_disability: params[:application][:vision_disability] == "1" || params[:application][:vision_disability] == true,
        speech_disability: params[:application][:speech_disability] == "1" || params[:application][:speech_disability] == true,
        mobility_disability: params[:application][:mobility_disability] == "1" || params[:application][:mobility_disability] == true,
        cognition_disability: params[:application][:cognition_disability] == "1" || params[:application][:cognition_disability] == true
      }

      # Debug logging for guardian attributes
      Rails.logger.debug "Update - Guardian checkbox value: #{params[:application][:is_guardian].inspect}"
      Rails.logger.debug "Update - Guardian relationship value: #{params[:application][:guardian_relationship].inspect}"

      # Store the user reference before transaction to ensure it's maintained
      user = current_user

      # Add debug logging
      Rails.logger.debug "Before transaction - Application user_id: #{@application.user_id}"
      Rails.logger.debug "Before transaction - Current user ID: #{user.id}"

      success = ActiveRecord::Base.transaction do
        begin
          # Explicitly ensure user association is maintained
          @application.user = user

          # Assign other attributes
          @application.assign_attributes(application_attrs)

          # Update user attributes first
          user_update_success = update_user_attributes(user_attrs)

          # Verify user association is still intact
          if @application.user_id.nil?
            Rails.logger.error "User association lost after attribute assignment"
            @application.user = user # Re-establish association if lost
          end

          if user_update_success && @application.save
            # Handle status changes - use the object directly instead of update!
            if params[:submit_application] && @application.draft?
              @application.status = :in_progress
              @application.save!
            end
            true
          else
            Rails.logger.error "Failed to save application: #{@application.errors.full_messages.join(', ')}"
            false
          end
        rescue ActiveRecord::RecordInvalid => e
          Rails.logger.error "Transaction failed: #{e.message}"
          Rails.logger.error "Application state: #{@application.attributes.inspect}"
          false
        end
      end

      if success
        # Log guardian relationship if applicable
        if current_user.is_guardian? && @application.persisted?
          Event.create!(
            user: current_user,
            action: "guardian_application_updated",
            metadata: {
              application_id: @application.id,
              guardian_relationship: current_user.guardian_relationship,
              timestamp: Time.current.iso8601
            }
          )
        end

        notice = if @application.status != original_status && @application.in_progress?
          "Application submitted successfully!"
        else
          "Application saved successfully."
        end
        redirect_to constituent_portal_application_path(@application), notice: notice
      else
        Rails.logger.debug "Application errors: #{@application.errors.full_messages}"

        # Create a medical_provider object for the form when validation fails
        @medical_provider = OpenStruct.new(
          name: params.dig(:application, :medical_provider, :name) || @application.medical_provider_name,
          phone: params.dig(:application, :medical_provider, :phone) || @application.medical_provider_phone,
          fax: params.dig(:application, :medical_provider, :fax) || @application.medical_provider_fax,
          email: params.dig(:application, :medical_provider, :email) || @application.medical_provider_email
        )

        render :edit, status: :unprocessable_entity
      end
    end

    def upload_documents
      @application = current_user.applications.find(params[:id])

      if params[:documents].present?
        params[:documents].each do |document_type, file|
          case document_type
          when "income_proof"
            @application.income_proof.attach(file)
          when "residency_proof"
            @application.residency_proof.attach(file)
          end
        end

        if @application.save
          redirect_to constituent_portal_application_path(@application),
            notice: "Documents uploaded successfully."
        else
          render :edit, status: :unprocessable_entity
        end
      else
        redirect_to constituent_portal_application_path(@application),
          alert: "Please select documents to upload."
      end
    end

    def request_review
      @application = current_user.applications.find(params[:id])

      if @application.update(needs_review_since: Time.current)
        # Notify admins about the review request
        User.where(type: "Admin").find_each do |admin|
          Notification.create!(
            recipient: admin,
            actor: current_user,
            action: "review_requested",
            notifiable: @application
          )
        end

        redirect_to constituent_portal_application_path(@application),
          notice: "Review requested successfully."
      else
        redirect_to constituent_portal_application_path(@application),
          alert: "Unable to request review at this time."
      end
    end

    def verify
      @application = current_user.applications.find(params[:id])
      render :verify
    end

    def submit
      @application = current_user.applications.find(params[:id])

      if @application.update(submission_params.merge(status: :in_progress))
        ApplicationNotificationsMailer.submission_confirmation(@application).deliver_now
        redirect_to constituent_portal_application_path(@application),
          notice: "Application submitted successfully!"
      else
        render :verify, status: :unprocessable_entity
      end
    end

    def resubmit_proof
      @application = current_user.applications.find(params[:id])

      if @application.resubmit_proof!
        redirect_to constituent_portal_application_path(@application),
          notice: "Proof resubmitted successfully"
      else
        redirect_to constituent_portal_application_path(@application),
          alert: "Failed to resubmit proof"
      end
    end

    def request_training
      @application = current_user.applications.find(params[:id])

      # Check if the application is approved and eligible for training
      unless @application.approved?
        redirect_to constituent_portal_dashboard_path,
          alert: "Only approved applications are eligible for training."
        return
      end

      # Check if the constituent has remaining training sessions
      max_training_sessions = Policy.get("max_training_sessions") || 3
      if @application.training_sessions.count >= max_training_sessions
        redirect_to constituent_portal_dashboard_path,
          alert: "You have used all of your available training sessions."
        return
      end

      # Create a notification for admins to schedule training
      User.where(type: "Admin").find_each do |admin|
        Notification.create!(
          recipient: admin,
          actor: current_user,
          action: "training_requested",
          notifiable: @application,
          metadata: {
            application_id: @application.id,
            constituent_id: current_user.id,
            constituent_name: current_user.full_name,
            timestamp: Time.current.iso8601
          }
        )
      end

      # Create an activity record for the constituent
      if defined?(Activity)
        Activity.create!(
          user: current_user,
          description: "Requested training session",
          metadata: {
            application_id: @application.id,
            timestamp: Time.current.iso8601
          }
        )
      end

      redirect_to constituent_portal_dashboard_path,
        notice: "Training request submitted. An administrator will contact you to schedule your session."
    end

    def fpl_thresholds
      # Get FPL thresholds from policies
      thresholds = {}
      (1..8).each do |size|
        policy = Policy.find_by(key: "fpl_#{size}_person")
        thresholds[size.to_s] = policy&.value.to_i
      end

      # Get FPL modifier percentage
      modifier = Policy.find_by(key: "fpl_modifier_percentage")&.value.to_i || 400

      render json: { thresholds: thresholds, modifier: modifier }
    end

    private

    def filtered_application_params
      application_params.except(
        :is_guardian,
        :guardian_relationship,
        :hearing_disability,
        :vision_disability,
        :speech_disability,
        :mobility_disability,
        :cognition_disability
      )
    end

    def submission_params
      params.require(:application).permit(
        :terms_accepted,
        :information_verified,
        :medical_release_authorized
      )
    end

    def set_application
      @application = current_user.applications.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to constituent_portal_dashboard_path, alert: "Application not found"
    end

    def ensure_editable
      unless @application.draft?
        redirect_to constituent_portal_application_path(@application),
                    alert: "This application has already been submitted and cannot be edited."
      end
    end

    def application_params
      params.require(:application).permit(
        :application_type,
        :submission_method,
        :maryland_resident,
        :annual_income,
        :household_size,
        :self_certify_disability,
        :residency_proof,
        :income_proof,
        :medical_provider_name,
        :medical_provider_phone,
        :medical_provider_fax,
        :medical_provider_email,
        :income_details,
        :residency_details,

        # Added verification fields
        :terms_accepted,
        :information_verified,
        :medical_release_authorized,

        # These will be moved to user_params
        :is_guardian,
        :guardian_relationship,
        :hearing_disability,
        :vision_disability,
        :speech_disability,
        :mobility_disability,
        :cognition_disability
      )
    end

    def user_params
      params.require(:application).permit(
        :is_guardian,
        :guardian_relationship,
        :hearing_disability,
        :vision_disability,
        :speech_disability,
        :mobility_disability,
        :cognition_disability
      ).transform_values { |v| ActiveModel::Type::Boolean.new.cast(v) }
    end

    def verification_params
      params.require(:application).permit(
        :terms_accepted,
        :information_verified,
        :medical_release_authorized
      )
    end

    def medical_provider_params
      return {} unless params[:medical_provider]

      params.require(:medical_provider).permit(
        :name,
        :phone,
        :fax,
        :email
      ).transform_keys { |key| "medical_provider_#{key}" }
    end

    def require_constituent!
      unless current_user&.constituent?
        redirect_to root_path, alert: "Access denied. Constituent-only area."
      end
    end

    def update_user_attributes(attrs)
      log_debug("Updating user attributes: #{attrs.inspect}")
      log_debug("Current user class: #{current_user.class}")
      log_debug("Current user attributes: #{current_user.attributes.keys}")

      # Process boolean values properly
      processed_attrs = {}

      # Handle is_guardian explicitly
      processed_attrs[:is_guardian] = attrs[:is_guardian] == true || attrs[:is_guardian] == "1"

      # Only set guardian_relationship if is_guardian is true
      if processed_attrs[:is_guardian]
        processed_attrs[:guardian_relationship] = attrs[:guardian_relationship]
      end

      # Process disability attributes
      processed_attrs[:hearing_disability] = ActiveModel::Type::Boolean.new.cast(attrs[:hearing_disability])
      processed_attrs[:vision_disability] = ActiveModel::Type::Boolean.new.cast(attrs[:vision_disability])
      processed_attrs[:speech_disability] = ActiveModel::Type::Boolean.new.cast(attrs[:speech_disability])
      processed_attrs[:mobility_disability] = ActiveModel::Type::Boolean.new.cast(attrs[:mobility_disability])
      processed_attrs[:cognition_disability] = ActiveModel::Type::Boolean.new.cast(attrs[:cognition_disability])

      # Log the processed attributes for debugging
      log_debug("Processed attributes: #{processed_attrs.inspect}")

      # Update the user with the processed attributes
      result = current_user.update(processed_attrs)

      # Log any errors
      unless result
        Rails.logger.error "Update failed."
        Rails.logger.error "Current user errors: #{current_user.errors.full_messages}"
      end

      # Verify the user's disability status after update
      if result
        log_debug("User disability status after update: hearing=#{current_user.hearing_disability}, vision=#{current_user.vision_disability}, speech=#{current_user.speech_disability}, mobility=#{current_user.mobility_disability}, cognition=#{current_user.cognition_disability}")
        log_debug("User has_disability_selected? returns: #{current_user.has_disability_selected?}")
      end

      result
    end

    # Cast boolean parameters to proper boolean values
    def cast_boolean_params
      return unless params[:application]

      # Handle self_certify_disability
      if params[:application][:self_certify_disability]
        value = params[:application][:self_certify_disability]
        # If it's an array, take the last value
        value = value.last if value.is_a?(Array)
        params[:application][:self_certify_disability] = ActiveModel::Type::Boolean.new.cast(value)
        log_debug("self_certify_disability after casting: #{params[:application][:self_certify_disability].inspect}")
      end

      # Handle other boolean parameters as needed
      # Example: params[:application][:other_boolean_field]
    end

    # Conditionally log debug messages based on environment
    def log_debug(message)
      Rails.logger.debug(message) if Rails.env.development? || Rails.env.test?
    end
  end
end
