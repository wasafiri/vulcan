module Applications
  # Service to handle paper application submissions.
  #
  # This service handles the creation of paper applications, including:
  # 1. Constituent creation/lookup
  # 2. Application record creation
  # 3. Proof attachment via ProofAttachmentService
  #
  # Note: We now use direct uploads exclusively, similar to the constituent portal.
  # Both paper and online submissions use ProofAttachmentService as the
  # single source of truth for proof attachments.
  class PaperApplicationService < BaseService
    attr_reader :params, :admin, :application, :constituent

    def initialize(params:, admin:)
      super()
      @params = params
      @admin = admin
      @application = nil
      @constituent = nil
    end

    def create
      begin
        # Step 1: Create constituent and application in a transaction
        success = false
        ActiveRecord::Base.transaction do
          find_or_create_constituent
          create_application
          success = @application.present? && @constituent.present?
        end
        
        unless success
          Rails.logger.error "Failed to create constituent or application"
          return false
        end
        
        # Verify application was created
        unless @application&.persisted?
          add_error("Application creation failed")
          return false
        end
        
        # Step 2: Handle proofs outside main transaction
        # This is critical - attachments need their own transaction boundary
        success = attach_proofs
        unless success
          # Log but continue - we created the application, just didn't attach proofs
          Rails.logger.error "Failed to attach one or more proofs for application #{@application.id}"
        end
        
        # Step 3: Send notifications (can fail without rolling back)
        begin
          send_notifications
        rescue StandardError => e
          # Log but don't fail the overall operation
          log_error(e, "Failed to send notifications, but application was created")
        end
        
        # Return true if we at least created the application
        true
      rescue StandardError => e
        log_error(e, "Failed to create paper application")
        false
      end
    end
  
    private
    
    # Attach proofs in separate transactions
    def attach_proofs
      success = true
      
      # Handle income proof if provided
      if params[:income_proof_action] == "accept"
        begin
          Rails.logger.info "Handling income proof attachment"
          success = handle_proof(:income) && success
        rescue => e
          log_error(e, "Failed to handle income proof")
          success = false
        end
      end
      
      # Handle residency proof if provided
      if params[:residency_proof_action] == "accept"
        begin
          Rails.logger.info "Handling residency proof attachment"
          success = handle_proof(:residency) && success
        rescue => e
          log_error(e, "Failed to handle residency proof")
          success = false
        end
      end
      
      success
    end

    def find_or_create_constituent
      constituent_attrs = params[:constituent]
      return add_error("Constituent params missing") unless constituent_attrs.present?

      @constituent = if constituent_attrs[:email].present?
                       Constituent.find_by(email: constituent_attrs[:email])
                     elsif constituent_attrs[:phone].present?
                       Constituent.find_by(phone: constituent_attrs[:phone])
                     end

      if @constituent
        # Check if constituent has active application
        if @constituent.active_application?
          return add_error("This constituent already has an active application.")
        end
      else
        # Create new constituent with temporary password
        temp_password = SecureRandom.hex(8)
        @constituent = Constituent.new(constituent_attrs)
        @constituent.password = temp_password
        @constituent.password_confirmation = temp_password
        @constituent.verified = true
        @constituent.force_password_change = true
        
        unless @constituent.save
          return add_error("Failed to create constituent: #{@constituent.errors.full_messages.join(', ')}")
        end

        # Send account creation notification
        ApplicationNotificationsMailer.account_created(@constituent, temp_password).deliver_later
      end
    end

    def create_application
      application_attrs = params[:application]
      return add_error("Application params missing") unless application_attrs.present?

      # Validate income threshold
      unless income_within_threshold?(application_attrs[:household_size], application_attrs[:annual_income])
        return add_error("Income exceeds the maximum threshold for the household size.")
      end

      @application = @constituent.applications.new(application_attrs)
      @application.submission_method = :paper
      @application.application_date = Time.current
      @application.status = :in_progress

      unless @application.save
        return add_error("Failed to create application: #{@application.errors.full_messages.join(', ')}")
      end
    end

    # Handles proof submission process for paper applications
    def handle_proof(type)
      action = params["#{type}_proof_action"]
      return true unless action.in?(%w[accept reject]) # Return success if no action needed

      begin
        if action == "accept"
          # Use the consistent ProofAttachmentService for attaching proofs
          Rails.logger.info "Paper application using ProofAttachmentService for #{type}_proof"
          
          # Get the file or signed_id from params
          file = params["#{type}_proof"]
          signed_id = params["#{type}_proof_signed_id"]
          
          unless file.present? || signed_id.present?
            Rails.logger.error "No #{type}_proof file or signed_id found in params"
            return add_error("Missing #{type} proof file")
          end
          
          # Log details if we have a file
          if file.present?
            Rails.logger.info "File details: Class=#{file.class.name}, Name=#{file.original_filename}, Type=#{file.content_type}, Size=#{file.size}"
          elsif signed_id.present?
            Rails.logger.info "Using signed_id for #{type}_proof: #{signed_id[0..20]}..."
          end
          
          # Determine what to pass to ProofAttachmentService (prefer signed_id if available)
          attachment_param = signed_id.present? ? signed_id : file
          
          # Use ProofAttachmentService for consistent handling
          result = ProofAttachmentService.attach_proof(
            application: @application,
            proof_type: type,
            blob_or_file: attachment_param,
            status: :approved, # Default to approved for paper applications
            admin: @admin,
            metadata: {
              submission_method: :paper,
              admin_id: @admin&.id
            }
          )
          
          # Check if the attachment was successful
          unless result[:success]
            error_message = "Failed to attach #{type} proof using ProofAttachmentService: #{result[:error]&.message}"
            Rails.logger.error error_message
            return add_error(error_message)
          end
          
          Rails.logger.info "Successfully attached #{type} proof for application #{@application.id}"
          return true
        elsif action == "reject"
          # Get the reason and notes from the params
          reason = params["#{type}_proof_rejection_reason"].presence || "other"
          notes = params["#{type}_proof_rejection_notes"].presence || "Rejected during paper application submission"
          
          # Use ProofAttachmentService for consistent rejection handling
          result = ProofAttachmentService.reject_proof_without_attachment(
            application: @application,
            proof_type: type,
            admin: @admin,
            reason: reason,
            notes: notes,
            metadata: {
              submission_method: :paper
            }
          )
          
          # Check if the rejection was successful
          unless result[:success]
            error_message = "Failed to reject #{type} proof: #{result[:error]&.message}"
            Rails.logger.error error_message
            return add_error(error_message)
          end
          
          Rails.logger.info "Successfully rejected #{type} proof for application #{@application.id}"
          return true
        end
        
        true # Default success
      rescue StandardError => e
        log_error(e, "Failed to handle #{type} proof")
        add_error("An unexpected error occurred while processing #{type} proof")
        false
      end
    end

    def send_notifications
      begin
        # Process each rejected proof review
        @application.proof_reviews.reload.each do |review|
          next unless review.status_rejected?
          
          begin
            # Send email notification but catch errors so processing can continue
            ApplicationNotificationsMailer.proof_rejected(@application, review).deliver_later
          rescue StandardError => e
            log_error(e, "Failed to send notification for review #{review.id}")
            # Continue with other reviews - notifications shouldn't block core functionality
          end
        end
      rescue StandardError => e
        # Log but don't re-raise - notifications shouldn't fail the application creation
        log_error(e, "Failed to process notifications")
      end
    end

    def income_within_threshold?(household_size, annual_income)
      return false unless household_size.present? && annual_income.present?
      
      # Get the base FPL amount for the household size
      base_fpl = Policy.get("fpl_#{[ household_size.to_i, 8 ].min}_person").to_i
  
      # Get the modifier percentage
      modifier = Policy.get("fpl_modifier_percentage").to_i
  
      # Calculate the threshold
      threshold = base_fpl * (modifier / 100.0)
  
      # Check if income is within threshold
      annual_income.to_f <= threshold
    end
  end
end
