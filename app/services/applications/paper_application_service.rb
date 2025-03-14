module Applications
  # Service to handle paper application submissions.
  #
  # This service handles the creation of paper applications, including:
  # 1. File validation and blob creation for proofs
  # 2. Constituent creation/lookup
  # 3. Application record creation
  # 4. Proof attachment via ProofAttachmentService
  #
  # Note: While this service handles file validation and blob creation,
  # the actual proof attachments are done through ProofAttachmentService
  # to maintain consistency with the constituent portal submission path.
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
        # Step 1: Pre-process files to create blobs
        proof_blobs = process_proof_files
        return false unless proof_blobs
        
        # Step 2: Create constituent and application in a transaction
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
        
        # Step 3: Handle proofs outside main transaction
        # This is critical - attachments need their own transaction boundary
        success = attach_proofs(proof_blobs)
        unless success
          # Log but continue - we created the application, just didn't attach proofs
          Rails.logger.error "Failed to attach one or more proofs for application #{@application.id}"
        end
        
        # Step 4: Send notifications (can fail without rolling back)
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
    
    # Process proof files separately to create blobs
    def process_proof_files
      proof_blobs = {}
      
      # Pre-process income proof if provided
      if params[:income_proof_action] == "accept" && params[:income_proof].present?
        begin
          Rails.logger.info "Pre-processing income proof for upload"
          proof_blobs[:income] = create_blob_from_uploaded_file(params[:income_proof], "income")
        rescue => e
          log_error(e, "Failed to process income proof file")
          return nil
        end
      end
      
      # Pre-process residency proof if provided
      if params[:residency_proof_action] == "accept" && params[:residency_proof].present?
        begin
          Rails.logger.info "Pre-processing residency proof for upload"
          proof_blobs[:residency] = create_blob_from_uploaded_file(params[:residency_proof], "residency")
        rescue => e
          log_error(e, "Failed to process residency proof file")
          return nil
        end
      end
      
      proof_blobs
    end
    
    # Attach proofs in separate transactions
    def attach_proofs(proof_blobs)
      success = true
      
      # Handle each proof separately to isolate failures
      if proof_blobs[:income]
        begin
          success = handle_proof(:income, proof_blobs[:income]) && success
        rescue => e
          log_error(e, "Failed to handle income proof")
          success = false
        end
      end
      
      if proof_blobs[:residency]
        begin
          success = handle_proof(:residency, proof_blobs[:residency]) && success
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

    def create_blob_from_uploaded_file(uploaded_file, type)
      # Validate file type
      unless ProofManageable::ALLOWED_TYPES.include?(uploaded_file.content_type)
        error_message = "Invalid file type for #{type} proof: #{uploaded_file.content_type}"
        Rails.logger.error error_message
        raise ActiveStorage::IntegrityError, error_message
      end
      
      # Validate file size
      if uploaded_file.size > ProofManageable::MAX_FILE_SIZE
        error_message = "File too large for #{type} proof: #{uploaded_file.size} bytes"
        Rails.logger.error error_message
        raise ActiveStorage::IntegrityError, error_message
      end
      
      # Create and upload the blob
      blob = ActiveStorage::Blob.create_and_upload!(
        io: uploaded_file,
        filename: uploaded_file.original_filename,
        content_type: uploaded_file.content_type
      )
      
      Rails.logger.info "Successfully created blob for #{type} proof: #{blob.id}"
      blob
    rescue ActiveStorage::IntegrityError => e
      Rails.logger.error "File integrity error when uploading #{type} proof: #{e.message}"
      raise
    rescue Aws::S3::Errors::ServiceError => e
      Rails.logger.error "S3 error when uploading #{type} proof: #{e.message}"
      Rails.logger.error "AWS Error Code: #{e.code}, Message: #{e.message}"
      raise
    rescue StandardError => e
      Rails.logger.error "Unexpected error when processing #{type} proof: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end

  # Handles proof submission process for paper applications
  # 
  # Note: This method pre-processes files and creates blobs, but the actual
  # attachment is delegated to ProofAttachmentService to maintain consistency
  # with the constituent portal submission path. Both paper and online submissions
  # use ProofAttachmentService as the single source of truth for proof attachments.
  def handle_proof(type, blob = nil)
    action = params["#{type}_proof_action"]
    return true unless action.in?(%w[accept reject]) # Return success if no action needed

    if action == "accept"
      # Make sure we have a blob or a file to process
      unless blob || params["#{type}_proof"].present?
        Rails.logger.error "No blob or #{type}_proof file provided for accept action"
        return add_error("No file provided for #{type} proof")
      end
      
      begin
        # Use the pre-uploaded blob if provided, otherwise create one
        actual_blob = blob
        if !actual_blob && params["#{type}_proof"].present?
          Rails.logger.info "Creating blob for #{type} proof from uploaded file"
          actual_blob = create_blob_from_uploaded_file(params["#{type}_proof"], type)
        end
        
        # Make sure we have a blob
        unless actual_blob
          error_message = "Failed to create or find blob for #{type} proof"
          Rails.logger.error error_message
          return add_error(error_message)
        end
        
        begin
          # Set paper application context flag to disable certain validations
          # This prevents issues with validation during the attachment process
          Thread.current[:paper_application_context] = true
          
          # Use the central ProofAttachmentService for all proof attachments
          Rails.logger.info "Using ProofAttachmentService to attach #{type} proof to application #{@application.id}"
          result = ProofAttachmentService.attach_proof(
            application: @application,
            proof_type: type,
            blob_or_file: actual_blob,
            status: :approved,  # Always approved for paper applications
            admin: @admin,
            metadata: {
              ip_address: '0.0.0.0', # Paper application doesn't have an IP
              submission_method: 'paper',
              paper_application_id: @application.id,
              blob_size: actual_blob.respond_to?(:byte_size) ? actual_blob.byte_size : nil
            }
          )
        ensure
          # Always reset the thread context flag
          Thread.current[:paper_application_context] = nil
        end
          
          # More detailed error handling and debugging
          unless result && result[:success]
            error_message = result&.dig(:error)&.message || "Failed to attach and approve #{type} proof"
            
            # Add detailed debugging info
            Rails.logger.error "ATTACHMENT ERROR: #{error_message}"
            Rails.logger.error "Error backtrace: #{result&.dig(:error)&.backtrace&.join("\n")}"
            Rails.logger.error "Blob details: #{actual_blob.inspect}" if actual_blob
            
            # Also check if the blob exists in ActiveStorage
            if actual_blob.is_a?(ActiveStorage::Blob)
              begin
                found_blob = ActiveStorage::Blob.find_by(id: actual_blob.id)
                Rails.logger.error "Blob found in database: #{found_blob.present?}"
                if found_blob
                  Rails.logger.error "Blob content type: #{found_blob.content_type}"
                  Rails.logger.error "Blob byte size: #{found_blob.byte_size}"
                  Rails.logger.error "Blob created at: #{found_blob.created_at}"
                end
              rescue => e
                Rails.logger.error "Error checking blob: #{e.message}"
              end
            end
            
            return add_error(error_message)
          end
          
          # Verify the attachment was successful - very important check
          @application.reload
          unless @application.send("#{type}_proof").attached?
            error_message = "Failed to verify #{type} proof attachment"
            Rails.logger.error error_message
            return add_error(error_message)
          end
          
          # Verify status was set correctly
          unless @application.send("#{type}_proof_status") == "approved"
            error_message = "Failed to set #{type} proof status to approved"
            Rails.logger.error error_message
            return add_error(error_message)
          end
          
          Rails.logger.info "Successfully attached and approved #{type} proof for application #{@application.id}"
          return true
        rescue => e
          Rails.logger.error "Error in handle_proof(#{type}): #{e.message}\n#{e.backtrace.join("\n")}"
          return add_error("Error processing #{type} proof: #{e.message}")
        end
        
      elsif action == "reject"
        # Get the reason and notes from the params
        reason = params["#{type}_proof_rejection_reason"].presence || "other"
        notes = params["#{type}_proof_rejection_notes"].presence || "Rejected during paper application submission"
        
        # Use a separate isolated transaction for rejection
        result = nil
        ActiveRecord::Base.transaction(requires_new: true) do
          # Use the ProofAttachmentService to handle rejection with telemetry
          result = ProofAttachmentService.reject_proof_without_attachment(
            application: @application,
            proof_type: type,
            admin: @admin,
            reason: reason,
            notes: notes,
            metadata: {
              ip_address: '0.0.0.0', # Paper application doesn't have an IP
              submission_method: 'paper',
              paper_application_id: @application.id
            }
          )
        end
        
        unless result && result[:success]
          error_message = result&.dig(:error)&.message || "Failed to reject #{type} proof"
          return add_error(error_message)
        end
        
        # Verify status was set correctly
        @application.reload
        unless @application.send("#{type}_proof_status") == "rejected"
          error_message = "Failed to set #{type} proof status to rejected"
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

    def create_proof_review(type, reason, notes)
      proof_review = @application.proof_reviews.build(
        admin: @admin,
        proof_type: type,
        status: :rejected,
        rejection_reason: reason.presence || 'other',
        notes: notes.presence || 'Rejected during paper application submission',
        submission_method: :paper,
        reviewed_at: Time.current
      )

      unless proof_review.save
        error_message = "Failed to create #{type} proof review: #{proof_review.errors.full_messages.join(', ')}"
        Rails.logger.error error_message
        raise ActiveRecord::RecordInvalid.new(proof_review)
      end

      proof_review
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
