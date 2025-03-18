module Applications
  # This service handles paper application submissions by administrators
  # It follows the same patterns as ConstituentPortal for file uploads
  class PaperApplicationService < BaseService
    attr_reader :params, :admin, :application, :constituent, :errors

    def initialize(params:, admin:)
      super()
      # Use with_indifferent_access to handle both symbol and string keys
      @params = params.with_indifferent_access
      @admin = admin
      @application = nil
      @constituent = nil
      @errors = []
    end

    def create
      success = ActiveRecord::Base.transaction do
        # Find or create the constituent (similar to constituent portal)
        return false unless process_constituent

        # Create application with proper context
        return false unless create_application

        # Process file uploads (direct attachment like constituent portal)
        return false unless process_proof_uploads

        # Send notifications as needed
        send_notifications if @application.persisted?
        
        # Log paper application creation specifically
        if @application.persisted?
          submission_time = Time.current
          Event.create!(
            user: @admin,
            action: 'application_created',
            metadata: {
              application_id: @application.id,
              submission_method: 'paper',
              initial_status: (@application.status || 'in_progress').to_s,
              timestamp: submission_time.iso8601
            }
          )
          
          # Create a specific audit log entry for the submission timestamp
          ProofSubmissionAudit.create!(
            application_id: @application.id,
            user_id: @admin.id,
            proof_type: 'application',
            ip_address: "0.0.0.0",
            metadata: {
              submission_method: 'paper',
              timestamp: submission_time.iso8601,
              action: 'submit'
            },
            submission_method: :paper,
            created_at: submission_time,
            updated_at: submission_time
          )
        end
        
        # Return success if we reach this point
        @application.persisted?
      end

      success
    rescue StandardError => e
      log_error(e, 'Failed to create paper application')
      @errors << e.message
      false
    end

    private

    def log_proof_debug_info(type)
      Rails.logger.debug "==== PROCESS_PROOF(#{type}) STARTED ===="
      Rails.logger.debug "Params class: #{params.class.name}"
      Rails.logger.debug "Params keys: #{params.keys.inspect}"
      Rails.logger.debug "Param key as symbol: #{params[:"#{type}_proof_action"].inspect}"
      Rails.logger.debug "Param key as string: #{params["#{type}_proof_action"].inspect}"
      Rails.logger.debug "File param present? #{params["#{type}_proof"].present?}"
      if params["#{type}_proof"].present?
        Rails.logger.debug "File param type: #{params["#{type}_proof"].class.name}"
        Rails.logger.debug "File param details: #{params["#{type}_proof"].inspect}"
      end
    end

    def extract_proof_action(type)
      params["#{type}_proof_action"] || params[:"#{type}_proof_action"]
    end

    def process_accept_proof(type)
      Rails.logger.debug "Accepting #{type} proof"
      if params["#{type}_proof"].present?
        result = ProofAttachmentService.attach_proof(
          application: @application,
          proof_type: type,
          blob_or_file: params["#{type}_proof"],
          status: :approved,
          admin: @admin,
          submission_method: :paper,
          metadata: {}
        )
        unless result[:success]
          add_error("Error processing #{type} proof: #{result[:error]&.message}")
          return false
        end
        Rails.logger.debug "Successfully attached #{type} proof for application #{@application.id}"
        true
      else
        Rails.logger.debug "No file provided for #{type}"
        add_error("Please upload a file for #{type} proof")
        false
      end
    end

    def process_reject_proof(type)
      Rails.logger.debug "Rejecting #{type} proof"
      result = ProofAttachmentService.reject_proof_without_attachment(
        application: @application,
        proof_type: type,
        admin: @admin,
        reason: params["#{type}_proof_rejection_reason"],
        notes: params["#{type}_proof_rejection_notes"],
        submission_method: :paper,
        metadata: {}
      )
      unless result[:success]
        Rails.logger.error "Error rejecting #{type} proof via service: #{result[:error]&.message}"
        add_error("Error rejecting #{type} proof: #{result[:error]&.message}")
        return false
      end
      Rails.logger.debug "Successfully rejected #{type} proof"
      true
    end

    def process_constituent
      constituent_params = params[:constituent]
      return add_error('Constituent params missing') unless constituent_params.present?

      # Find existing constituent by email or phone
      if constituent_params[:email].present?
        @constituent = Constituent.find_by(email: constituent_params[:email])
      elsif constituent_params[:phone].present?
        @constituent = Constituent.find_by(phone: constituent_params[:phone])
      end

      if @constituent
        # For existing constituent, check for active application
        if @constituent.active_application?
          add_error("This constituent already has an active application.")
          return false
        end
        return true
      end

      # Create new constituent if not found
      create_new_constituent(constituent_params)
    end

    def create_new_constituent(attrs)
      # Ensure at least one disability flag is set for new constituents
      ensure_disability_selection(attrs)
      
      # Generate temporary password for new accounts
      temp_password = SecureRandom.hex(8)
      
      # Create the constituent using the Constituent class directly to ensure proper type
      @constituent = Constituent.new(attrs).tap do |c|
        c.password = temp_password
        c.password_confirmation = temp_password
        c.verified = true
        c.force_password_change = true
        # No need to set type as it will automatically be "Constituent" based on class name
      end
      
      Rails.logger.debug "Creating new constituent with type: #{@constituent.type}"

      if @constituent.save
        # Send account creation notification
        ApplicationNotificationsMailer.account_created(@constituent, temp_password).deliver_later
        true
      else
        add_error("Failed to create constituent: #{@constituent.errors.full_messages.join(', ')}")
        false
      end
    end

    def ensure_disability_selection(attrs)
      has_any_disability = [:hearing_disability, :vision_disability, :speech_disability, 
                          :mobility_disability, :cognition_disability].any? do |disability|
        attrs[disability] == '1' || attrs[disability] == true
      end
      
      # Default to hearing disability if none are selected
      attrs[:hearing_disability] = '1' unless has_any_disability
    end

    def create_application
      # Set the paper application context flag
      Thread.current[:paper_application_context] = true
      
      begin
        application_attrs = params[:application]
        return add_error('Application params missing') unless application_attrs.present?

        # Validate income thresholds
        unless income_within_threshold?(application_attrs[:household_size], application_attrs[:annual_income])
          return add_error('Income exceeds the maximum threshold for the household size.')
        end

        # Ensure constituent is fresh
        @constituent.reload
        
        # Build application with constituent association
        @application = @constituent.applications.new(application_attrs)
        @application.submission_method = :paper
        @application.application_date = Time.current
        @application.status = :in_progress
        
        # Double check the user association
        @application.user = @constituent
        
        unless @application.save
          add_error("Failed to create application: #{@application.errors.full_messages.join(', ')}")
          return false
        end
        
        true
      ensure
        # Always clear the thread-local variable
        Thread.current[:paper_application_context] = nil
      end
    end

    def process_proof_uploads
      # Set paper application context again
      Thread.current[:paper_application_context] = true
      
      # Enhanced debugging
      Rails.logger.debug "==== PAPER APPLICATION PROOF UPLOAD STARTED ===="
      Rails.logger.debug "Current params: #{params.inspect}"
      
      begin
        # Process income proof
        Rails.logger.debug "About to process income proof"
        income_result = process_proof(:income) 
        Rails.logger.debug "Income proof processing result: #{income_result}"
        
        # Process residency proof
        Rails.logger.debug "About to process residency proof"
        residency_result = process_proof(:residency)
        Rails.logger.debug "Residency proof processing result: #{residency_result}"
        
        # Return true if we reach here
        Rails.logger.debug "==== PAPER APPLICATION PROOF UPLOAD FINISHED ===="
        true
      ensure
        # Always clear the thread-local variable
        Thread.current[:paper_application_context] = nil
      end
    end

    def process_proof(type)
      log_proof_debug_info(type)
      action = extract_proof_action(type)
      Rails.logger.debug "Action determined: #{action.inspect}"

      unless %w[accept reject].include?(action)
        Rails.logger.debug "No valid action for #{type}, returning true"
        return true
      end

      result = case action
               when 'accept'
                 process_accept_proof(type)
               when 'reject'
                 process_reject_proof(type)
               end

      Rails.logger.debug "==== PROCESS_PROOF(#{type}) COMPLETED SUCCESSFULLY ===="
      result
    end

    def create_proof_review(type, status)
      @application.proof_reviews.create!(
        admin: @admin,
        proof_type: type,
        status: status,
        rejection_reason: status == :rejected ? params["#{type}_proof_rejection_reason"] : nil,
        notes: status == :rejected ? params["#{type}_proof_rejection_notes"] : nil,
        submission_method: :paper,
        reviewed_at: Time.current
      )
    end

    def send_notifications
      @application.proof_reviews.reload.each do |review|
        if review.status_rejected?
          ApplicationNotificationsMailer.proof_rejected(@application, review).deliver_later
        end
      end
    end

    def income_within_threshold?(household_size, annual_income)
      return false unless household_size.present? && annual_income.present?

      base_fpl = Policy.get("fpl_#{[household_size.to_i, 8].min}_person").to_i
      modifier = Policy.get("fpl_modifier_percentage").to_i
      threshold = base_fpl * (modifier / 100.0)

      annual_income.to_f <= threshold
    end

    def add_error(message)
      @errors << message
      false
    end

    def log_error(exception, message)
      Rails.logger.error "#{message}: #{exception.message}"
      Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
    end
  end
end
