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
        # Use the pre-uploaded blob if provided
        if blob
          # Attach the blob to the application
          @application.send("#{type}_proof").attach(blob)
          
          # Verify attachment was successful by reloading and checking
          @application.send("#{type}_proof").reload
          
          unless @application.send("#{type}_proof").attached?
            error_message = "Failed to attach #{type} proof - verification failed after attach"
            Rails.logger.error error_message
            raise StandardError, error_message
          end
          
          # Only update status if attachment verification succeeds
          @application.update!("#{type}_proof_status" => :approved)
          
          Rails.logger.info "Successfully attached and approved #{type} proof for application #{@application.id}"
        elsif params["#{type}_proof"].present?
          # This is a fallback if blob wasn't pre-processed
          # This shouldn't normally happen with our improved flow
          Rails.logger.warn "No pre-processed blob for #{type} proof, creating one now (unexpected)"
          
          # Create and upload blob
          blob = create_blob_from_uploaded_file(params["#{type}_proof"], type)
          
          # Attach and verify
          @application.send("#{type}_proof").attach(blob)
          @application.send("#{type}_proof").reload
          
          unless @application.send("#{type}_proof").attached?
            error_message = "Failed to attach #{type} proof in fallback path"
            Rails.logger.error error_message
            raise StandardError, error_message
          end
          
          @application.update!("#{type}_proof_status" => :approved)
        end
      elsif action == "reject"
        @application.update!("#{type}_proof_status" => :rejected)
        create_proof_review(
          type,
          params["#{type}_proof_rejection_reason"],
          params["#{type}_proof_rejection_notes"]
        )
      end
    rescue StandardError => e
      log_error(e, "Failed to handle #{type} proof")
      raise
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
      @application.proof_reviews.reload.each do |review|
        next unless review.status_rejected?

        ApplicationNotificationsMailer.proof_rejected(
          @application,
          review
        ).deliver_later
      end
    rescue StandardError => e
      log_error(e, "Failed to send notifications")
      # Don't re-raise - we don't want to fail if notifications fail
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
