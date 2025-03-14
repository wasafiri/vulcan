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
    # 
    # Uses the same approach as constituent portal, passing signed_ids directly
    # to ProofAttachmentService
    def handle_proof(type)
      action = params["#{type}_proof_action"]
      return true unless action.in?(%w[accept reject]) # Return success if no action needed

      if action == "accept"
        begin
          # Use ProofAttachmentService to handle the attachment
          Rails.logger.info "Using ProofAttachmentService for #{type} proof attachment"
          
          # Now giving priority to the regular file upload since we've removed direct upload functionality
          blob_or_file = nil
          
          if params["#{type}_proof"].present?
            blob_or_file = params["#{type}_proof"]
            Rails.logger.info "Using file upload for #{type} proof: #{blob_or_file.class.name}"
          # Fallback: signed_id from direct upload (for backward compatibility)
          elsif params["#{type}_proof_signed_id"].present?
            blob_or_file = params["#{type}_proof_signed_id"]
            Rails.logger.info "Found signed_id for #{type} proof: #{blob_or_file}"
          else
            Rails.logger.error "No #{type}_proof parameter provided"
            return add_error("No file provided for #{type} proof")
          end
          
          Rails.logger.info "Using blob_or_file: #{blob_or_file.class.name}" if blob_or_file.present?
          
          result = ProofAttachmentService.attach_proof(
            application: @application,
            proof_type: type,
            blob_or_file: blob_or_file,
            status: :approved,  # Always approved for paper applications
            admin: @admin,
            metadata: {
              ip_address: '0.0.0.0', # Paper application doesn't have an IP
              submission_method: 'paper',
              paper_application_id: @application.id
            }
          )
          
          # Error handling and verification
          unless result && result[:success]
            error_message = result&.dig(:error)&.message || "Failed to attach and approve #{type} proof"
            Rails.logger.error "ATTACHMENT ERROR: #{error_message}"
            return add_error(error_message)
          end
          
          # Check if the attachment was truly successful by looking directly at the attachments table
          attachment_exists = ActiveStorage::Attachment.where(
            record_type: 'Application',
            record_id: @application.id,
            name: "#{type}_proof"
          ).exists?
          
          unless attachment_exists
            Rails.logger.warn "Attachment record not found for #{type}_proof - fixing now"
            
            # Determine the blob ID to use
            blob_id = nil
            
            if blob_or_file.is_a?(String) && blob_or_file.start_with?("eyJf")
              # It's a signed_id, find the actual blob
              blob_id = ActiveStorage::Blob.find_signed(blob_or_file)&.id
              Rails.logger.info "Found blob ID #{blob_id} from signed_id"
            elsif blob_or_file.respond_to?(:id) && blob_or_file.is_a?(ActiveStorage::Blob)
              # It's already a blob object
              blob_id = blob_or_file.id
              Rails.logger.info "Using direct blob ID #{blob_id}"
            end
            
            if blob_id.present?
              # Directly create the attachment record
              Rails.logger.info "Creating missing attachment record for #{type}_proof with blob ID #{blob_id}"
              ActiveStorage::Attachment.create!(
                name: "#{type}_proof",
                record_type: 'Application',
                record_id: @application.id,
                blob_id: blob_id
              )
            else
              error_message = "Failed to determine blob ID for #{type}_proof"
              Rails.logger.error error_message
              return add_error(error_message)
            end
          end
          
          # Reload the application to refresh attachments
          @application = Application.uncached { Application.find(@application.id) }
          
          # Verify the attachment exists after our fix
          unless @application.send("#{type}_proof").attached?
            error_message = "Failed to verify #{type}_proof attachment after fixing records"
            Rails.logger.error error_message
            return add_error(error_message)
          end
          
          # Verify status was set correctly
          unless @application.send("#{type}_proof_status") == "approved"
            # Manually set the status if it's not right
            @application.update_column("#{type}_proof_status", Application.send("#{type}_proof_statuses")[:approved])
            Rails.logger.warn "Had to manually set #{type} proof status to approved"
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
