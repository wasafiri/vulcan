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
        ActiveRecord::Base.transaction do
          find_or_create_constituent
          create_application
          handle_proofs
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

    def handle_proofs
      handle_proof(:income)
      handle_proof(:residency)
    end

    def handle_proof(type)
      action = params["#{type}_proof_action"]
      return unless action.in?(%w[accept reject])

      if action == "accept" && params["#{type}_proof"].present?
        @application.send("#{type}_proof").attach(params["#{type}_proof"])
        @application.update!("#{type}_proof_status" => :approved)
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
