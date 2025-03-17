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
          Rails.logger.error 'Failed to create constituent or application'
          return false
        end

        # Verify application was created
        unless @application&.persisted?
          add_error('Application creation failed')
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
          log_error(e, 'Failed to send notifications, but application was created')
        end

        # Return true if we at least created the application
        true
      rescue StandardError => e
        log_error(e, 'Failed to create paper application')
        false
      end
    end

    private

    # Attach proofs in separate transactions
    def attach_proofs
      income_success = process_proof(:income, :income_proof_action)
      residency_success = process_proof(:residency, :residency_proof_action)
      income_success && residency_success
    end

    def process_proof(proof_type, action_param)
      return true unless params[action_param] == 'accept'

      Rails.logger.info "Handling #{proof_type} proof attachment"
      handle_proof(proof_type)
    rescue StandardError => e
      log_error(e, "Failed to handle #{proof_type} proof")
      false
    end

    def find_or_create_constituent
      constituent_attrs = params[:constituent]
      return add_error('Constituent params missing') unless constituent_attrs.present?

      constituent = find_constituent(constituent_attrs)
      return add_error("This constituent already has an active application.") if constituent&.active_application?
      return constituent if constituent

      create_new_constituent(constituent_attrs)
    end

    def find_constituent(attrs)
      return Constituent.find_by(email: attrs[:email]) if attrs[:email].present?
      return Constituent.find_by(phone: attrs[:phone]) if attrs[:phone].present?

      nil
    end

    def create_new_constituent(attrs)
      temp_password = SecureRandom.hex(8)
      constituent = Constituent.new(attrs).tap do |c|
        c.password = temp_password
        c.password_confirmation = temp_password
        c.verified = true
        c.force_password_change = true
      end

      return add_error("Failed to create constituent: #{constituent.errors.full_messages.join(', ')}") unless constituent.save

      ApplicationNotificationsMailer.account_created(constituent, temp_password).deliver_later
      constituent
    end

    def create_application
      application_attrs = params[:application]
      return add_error('Application params missing') unless application_attrs.present?

      return add_error('Income exceeds the maximum threshold for the household size.') unless income_within_threshold?(application_attrs[:household_size], application_attrs[:annual_income])

      @application = build_application(application_attrs)
      add_error("Failed to create application: #{@application.errors.full_messages.join(', ')}") unless @application.save
    end

    def handle_proof(type)
      action = params["#{type}_proof_action"]
      return true unless action.in?(%w[accept reject])
    
      begin
        case action
        when 'accept'
          process_accept_proof(type)
        when 'reject'
          process_reject_proof(type)
        else
          true
        end
      rescue StandardError => e
        log_error(e, "Failed to handle #{type} proof")
        add_error("An unexpected error occurred while processing #{type} proof")
        false
      end
    end

    def send_notifications
      @application.proof_reviews.reload.each do |review|
        next unless review.status_rejected?

        begin
          ApplicationNotificationsMailer.proof_rejected(@application, review).deliver_later
        rescue StandardError => e
          log_error(e, "Failed to send notification for review #{review.id}")
        end
      end
    rescue StandardError => e
      log_error(e, 'Failed to process notifications')
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

  private

  def build_application(attrs)
    app = @constituent.applications.new(attrs)
    app.submission_method = :paper
    app.application_date = Time.current
    app.status = :in_progress
    app
  end

  def process_accept_proof(type)
    Rails.logger.info "Paper application using ProofAttachmentService for #{type}_proof"
    result = ProofAttachmentService.attach_proof(
      application: @application,
      proof_type: type,
      blob_or_file: params["#{type}_proof"],
      status: :approved,
      admin: @admin,
      metadata: {
        submission_method: :paper,
        admin_id: @admin&.id
      }
    )

    unless result[:success]
      error_message = "Failed to attach #{type} proof using ProofAttachmentService: #{result[:error]&.message}"
      Rails.logger.error error_message
      return add_error(error_message)
    end

    Rails.logger.info "Successfully attached #{type} proof for application #{@application.id}"
    true
  end

  def process_reject_proof(type)
    reason = params["#{type}_proof_rejection_reason"].presence || 'other'
    notes  = params["#{type}_proof_rejection_notes"].presence  || 'Rejected during paper application submission'

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

    unless result[:success]
      error_message = "Failed to reject #{type} proof: #{result[:error]&.message}"
      Rails.logger.error error_message
      return add_error(error_message)
    end

    Rails.logger.info "Successfully rejected #{type} proof for application #{@application.id}"
    true
  end
end
