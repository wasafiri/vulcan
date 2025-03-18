require "ostruct"

module ConstituentPortal
  class ApplicationsController < ApplicationController
    before_action :authenticate_user!, except: [:fpl_thresholds]
    before_action :require_constituent!, except: [:fpl_thresholds]
    before_action :set_application, only: [:show, :edit, :update, :verify, :submit]
    before_action :ensure_editable, only: [:edit, :update]
    before_action :cast_boolean_params, only: [:create, :update]

    # Override current_user for tests
    def current_user
      if Rails.env.test? && ENV["TEST_USER_ID"].present?
        @current_user ||= User.find_by(id: ENV["TEST_USER_ID"])
        return @current_user if @current_user
      end
      super
    end

    def index
      @applications = current_user.applications.order(created_at: :desc)
    end

    def show
      @certification_requests = Notification.where(
        notifiable: @application, 
        action: "medical_certification_requested"
      ).order(created_at: :desc)
    end

    def new
      @application = current_user.applications.new
    end

  def create
    # Extract user attributes from params
    user_attrs = extract_user_attributes(params)
    
    # This will hold our application
    @application = nil
    
    success = ActiveRecord::Base.transaction do
      # Step 1: Update and save user attributes FIRST
      unless update_user_attributes(user_attrs)
        # User update failed, add errors
        @application = current_user.applications.new(filtered_application_params)
        @application.errors.merge!(current_user.errors)
        return false
      end
      
      # Force reload the user after successfully saving attributes
      current_user.reload
      
      # Step 2: Now create the application with the updated user
      @application = current_user.applications.new(filtered_application_params)
      set_initial_application_attributes(@application)
      
      # Log for debugging 
      debug_application_info(@application, params)
      
      # Step 3: Validate and save the application
      if @application.valid?
        @application.save!
        
        # Log the initial application creation
        Event.create!(
          user: current_user,
          action: 'application_created',
          metadata: {
            application_id: @application.id,
            submission_method: 'online',
            initial_status: @application.status,
            timestamp: Time.current.iso8601
          }
        )
        
        true
      else
        # Application validation failed
        Rails.logger.debug "Application validation errors: #{@application.errors.full_messages}"
        false
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Transaction failed: #{e.message}"
      false
    end

      if success
        log_guardian_event if current_user.is_guardian? && @application.persisted?
        redirect_to_app(@application)
      else
        build_medical_provider_for_form
        render :new, status: :unprocessable_entity
      end
  end

    def edit; end

    def update
      original_status = @application.status

      Rails.logger.debug "Update params: #{params.inspect}"
      Rails.logger.debug "Submit application param: #{params[:submit_application].inspect}"

      # Prepare application attributes using filtered_application_params.
      application_attrs = filtered_application_params.merge(
        annual_income: params[:application][:annual_income]&.gsub(/[^\d.]/, "")
      )

      # (No separate handling for medical provider keys is needed anymore.)

      user_attrs = {
        is_guardian: params[:application][:is_guardian] == "1" || params[:application][:is_guardian] == true,
        guardian_relationship: params[:application][:guardian_relationship],
        hearing_disability: params[:application][:hearing_disability] == "1" || params[:application][:hearing_disability] == true,
        vision_disability: params[:application][:vision_disability] == "1" || params[:application][:vision_disability] == true,
        speech_disability: params[:application][:speech_disability] == "1" || params[:application][:speech_disability] == true,
        mobility_disability: params[:application][:mobility_disability] == "1" || params[:application][:mobility_disability] == true,
        cognition_disability: params[:application][:cognition_disability] == "1" || params[:application][:cognition_disability] == true
      }

      Rails.logger.debug "Update - Guardian checkbox value: #{params[:application][:is_guardian].inspect}"
      Rails.logger.debug "Update - Guardian relationship value: #{params[:application][:guardian_relationship].inspect}"

      user = current_user
      Rails.logger.debug "Before transaction - Application user_id: #{@application.user_id}"
      Rails.logger.debug "Before transaction - Current user ID: #{user.id}"

      success = ActiveRecord::Base.transaction do
        begin
          @application.user = user
          @application.assign_attributes(application_attrs)

          user_update_success = update_user_attributes(user_attrs)

          if @application.user_id.nil?
            Rails.logger.error "User association lost after attribute assignment"
            @application.user = user
          end

          if user_update_success && @application.save
            if params[:submit_application].present? && @application.draft?
              Rails.logger.debug "Setting application status to in_progress"
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
      success = ActiveRecord::Base.transaction do
        # Track which proofs were processed for better user feedback
        processed_proofs = []
        
        params[:documents].each do |document_type, file|
          case document_type
          when "income_proof"
            # Use the shared ProofAttachmentService for consistency with paper applications
            result = ProofAttachmentService.attach_proof(
              application: @application,
              proof_type: :income,
              blob_or_file: file,
              status: :not_reviewed, # Default status for constituent uploads
              admin: nil, # No admin for constituent uploads
              submission_method: :web,
              metadata: { 
                ip_address: request.remote_ip
              }
            )
            return false unless result[:success]
            processed_proofs << "income"
            
          when "residency_proof"
            # Use the shared ProofAttachmentService for consistency with paper applications
            result = ProofAttachmentService.attach_proof(
              application: @application,
              proof_type: :residency,
              blob_or_file: file,
              status: :not_reviewed, # Default status for constituent uploads
              admin: nil, # No admin for constituent uploads
              submission_method: :web,
              metadata: { 
                ip_address: request.remote_ip
              }
            )
            return false unless result[:success]
            processed_proofs << "residency"
          end
        end
        
        # We can add more complex logic here if needed, e.g. requesting review
        @application.reload.save!
        
        # Store processed proofs in flash for better user feedback
        flash[:processed_proofs] = processed_proofs
        
        true # Return true to indicate successful transaction
      end

      if success
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
        ApplicationNotificationsMailer.submission_confirmation(@application).deliver_later
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
      unless @application.approved?
        redirect_to constituent_portal_dashboard_path,
                    alert: "Only approved applications are eligible for training."
        return
      end

      max_training_sessions = Policy.get("max_training_sessions") || 3
      if @application.training_sessions.count >= max_training_sessions
        redirect_to constituent_portal_dashboard_path,
                    alert: "You have used all of your available training sessions."
        return
      end

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

      Activity.create!(
        user: current_user,
        description: "Requested training session",
        metadata: {
          application_id: @application.id,
          timestamp: Time.current.iso8601
        }
      ) if defined?(Activity)

      redirect_to constituent_portal_dashboard_path,
                  notice: "Training request submitted. An administrator will contact you to schedule your session."
    end

    def fpl_thresholds
      thresholds = {}
      (1..8).each do |size|
        policy = Policy.find_by(key: "fpl_#{size}_person")
        thresholds[size.to_s] = policy&.value.to_i
      end
      modifier = Policy.find_by(key: "fpl_modifier_percentage")&.value.to_i || 400
      render json: { thresholds: thresholds, modifier: modifier }
    end

    private

    def set_initial_application_attributes(app)
      app.status = params[:submit_application] ? :in_progress : :draft
      app.application_date = Time.current
      app.submission_method = :online
      app.application_type ||= :new
    end

    def extract_user_attributes(p)
      {
        is_guardian: p[:application][:is_guardian] == "1" || p[:application][:is_guardian] == true,
        guardian_relationship: p[:application][:guardian_relationship],
        hearing_disability: p[:application][:hearing_disability] == "1" || p[:application][:hearing_disability] == true,
        vision_disability: p[:application][:vision_disability] == "1" || p[:application][:vision_disability] == true,
        speech_disability: p[:application][:speech_disability] == "1" || p[:application][:speech_disability] == true,
        mobility_disability: p[:application][:mobility_disability] == "1" || p[:application][:mobility_disability] == true,
        cognition_disability: p[:application][:cognition_disability] == "1" || p[:application][:cognition_disability] == true
      }
    end

    def debug_application_info(app, p)
      Rails.logger.debug "Guardian checkbox value: #{p[:application][:is_guardian].inspect}"
      Rails.logger.debug "Guardian relationship value: #{p[:application][:guardian_relationship].inspect}"
      Rails.logger.debug "Application attributes before save: #{app.attributes.inspect}"
      Rails.logger.debug "Medical provider attributes: #{p.dig(:application, :medical_provider_attributes).inspect}"
      Rails.logger.debug "Application valid? #{app.valid?}"
      Rails.logger.debug "Application errors: #{app.errors.full_messages}" if app.invalid?
    end

    def log_guardian_event
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

    def redirect_to_app(app)
      notice = params[:submit_application] ? "Application submitted successfully!" : "Application saved as draft."
      redirect_to constituent_portal_application_path(app), notice: notice
    end

    def build_medical_provider_for_form
      @medical_provider = OpenStruct.new(
        name: params.dig(:medical_provider, :name) || params.dig(:application, :medical_provider, :name),
        phone: params.dig(:medical_provider, :phone) || params.dig(:application, :medical_provider, :phone),
        fax: params.dig(:medical_provider, :fax) || params.dig(:application, :medical_provider, :fax),
        email: params.dig(:medical_provider, :email) || params.dig(:application, :medical_provider, :email)
      )
    end

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
      base_params = params.require(:application).permit(
        :application_type,
        :submission_method,
        :maryland_resident,
        :annual_income,
        :household_size,
        :self_certify_disability,
        :residency_proof,
        :income_proof,
        :income_details,
        :residency_details,
        :terms_accepted,
        :information_verified,
        :medical_release_authorized,
        :is_guardian,
        :guardian_relationship,
        :hearing_disability,
        :vision_disability,
        :speech_disability,
        :mobility_disability,
        :cognition_disability,
        medical_provider_attributes: [:name, :phone, :fax, :email]
      )
      if base_params[:medical_provider_attributes].present?
        mp = base_params.delete(:medical_provider_attributes)
        base_params.merge(mp.transform_keys { |key| "medical_provider_#{key}" })
      else
        base_params
      end
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
      if params.dig(:application, :medical_provider_attributes).present?
        params[:application].require(:medical_provider_attributes)
              .permit(:name, :phone, :fax, :email)
              .transform_keys { |key| "medical_provider_#{key}" }
      else
        {}
      end
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

      processed_attrs = {}
      processed_attrs[:is_guardian] = ActiveModel::Type::Boolean.new.cast(attrs[:is_guardian])
      processed_attrs[:guardian_relationship] = attrs[:guardian_relationship] if processed_attrs[:is_guardian]

      %i[hearing_disability vision_disability speech_disability mobility_disability cognition_disability].each do |attr|
        processed_attrs[attr] = ActiveModel::Type::Boolean.new.cast(attrs[attr])
      end

      log_debug("Processed attributes: #{processed_attrs.inspect}")

      begin
        # IMPORTANT: Always ensure type is "Constituent" for the constituent? method to work
        # This follows Rails STI conventions for role checks (see User#constituent? method)
        if current_user.type != "Constituent" && (current_user.is_a?(Constituent) || current_user.is_a?(Users::Constituent))
          processed_attrs[:type] = "Constituent"
          log_debug("Ensuring user type is set to 'Constituent' (was: #{current_user.type})")
        end
        
        # Use update! for reliability and consistent validation
        current_user.update!(processed_attrs)
        current_user.reload
        
        log_debug("User type after update: #{current_user.type}")
        log_debug("User is a constituent? #{current_user.constituent?}")
        log_debug("User disability status after update: hearing=#{current_user.hearing_disability}, vision=#{current_user.vision_disability}, " \
                  "speech=#{current_user.speech_disability}, mobility=#{current_user.mobility_disability}, cognition=#{current_user.cognition_disability}")
        log_debug("User has_disability_selected? returns: #{current_user.has_disability_selected?}")
        true
      rescue StandardError => e
        Rails.logger.error("Update failed: #{e.message}")
        false
      end
    end

    def cast_boolean_params
      return unless params[:application]
      boolean_fields = [
        :self_certify_disability,
        :hearing_disability,
        :vision_disability,
        :speech_disability,
        :mobility_disability,
        :cognition_disability,
        :is_guardian,
        :maryland_resident,
        :terms_accepted,
        :information_verified,
        :medical_release_authorized
      ]
      boolean_fields.each do |field|
        next unless params[:application][field]
        value = params[:application][field]
        value = value.last if value.is_a?(Array)
        params[:application][field] = ActiveModel::Type::Boolean.new.cast(value)
        log_debug("#{field} after casting: #{params[:application][field].inspect}")
      end
    end

    def log_debug(message)
      Rails.logger.debug(message) if Rails.env.development? || Rails.env.test?
    end
  end
end
