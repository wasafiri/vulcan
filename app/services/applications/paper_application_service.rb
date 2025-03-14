module Applications
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
      # First, validate and upload any proof files outside the transaction
      # This is because file uploads can be slow and we don't want to hold a DB transaction
      proof_blobs = {}
      
      # Pre-process income proof if provided
      if params[:income_proof_action] == "accept" && params[:income_proof].present?
        begin
          Rails.logger.info "Pre-processing income proof for upload"
          proof_blobs[:income] = create_blob_from_uploaded_file(params[:income_proof], "income")
        rescue => e
          log_error(e, "Failed to process income proof file")
          return false
        end
      end
      
      # Pre-process residency proof if provided
      if params[:residency_proof_action] == "accept" && params[:residency_proof].present?
        begin
          Rails.logger.info "Pre-processing residency proof for upload"
          proof_blobs[:residency] = create_blob_from_uploaded_file(params[:residency_proof], "residency")
        rescue => e
          log_error(e, "Failed to process residency proof file")
          return false
        end
      end
      
      # Now do the database work in a transaction
      ActiveRecord::Base.transaction do
        find_or_create_constituent
        create_application
        handle_proofs(proof_blobs)
        send_notifications
      end
      
      true
    rescue StandardError => e
      log_error(e, "Failed to create paper application")
      false
    end
  end

    private

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

    def handle_proofs(proof_blobs = {})
      handle_proof(:income, proof_blobs[:income])
      handle_proof(:residency, proof_blobs[:residency])
    end

    def handle_proof(type, blob = nil)
      action = params["#{type}_proof_action"]
      return unless action.in?(%w[accept reject])

      if action == "accept"
        # Make sure we have a blob or a file to process
        unless blob || params["#{type}_proof"].present?
          Rails.logger.error "No blob or #{type}_proof file provided for accept action"
          return add_error("No file provided for #{type} proof")
        end
        
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
        
        # Use the ProofAttachmentService to handle attachment with telemetry
        result = ProofAttachmentService.attach_proof(
          application: @application,
          proof_type: type,
          blob_or_file: actual_blob,
          status: :approved,
          admin: @admin,
          metadata: {
            ip_address: '0.0.0.0', # Paper application doesn't have an IP
            submission_method: 'paper',
            paper_application_id: @application.id
          }
        )
        
        unless result[:success]
          error_message = result[:error]&.message || "Failed to attach and approve #{type} proof"
          return add_error(error_message)
        end
        
        Rails.logger.info "Successfully attached and approved #{type} proof for application #{@application.id}"
        
      elsif action == "reject"
        # Get the reason and notes from the params
        reason = params["#{type}_proof_rejection_reason"].presence || "other"
        notes = params["#{type}_proof_rejection_notes"].presence || "Rejected during paper application submission"
        
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
        
        unless result[:success]
          error_message = result[:error]&.message || "Failed to reject #{type} proof"
          return add_error(error_message)
        end
        
        Rails.logger.info "Successfully rejected #{type} proof for application #{@application.id}"
      end
    rescue StandardError => e
      log_error(e, "Failed to handle #{type} proof")
      add_error("An unexpected error occurred while processing #{type} proof")
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
