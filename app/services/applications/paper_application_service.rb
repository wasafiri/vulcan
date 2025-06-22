# frozen_string_literal: true

module Applications
  # This service handles paper application submissions by administrators
  # It follows the same patterns as ConstituentPortal for file uploads
  class PaperApplicationService < BaseService
    include Rails.application.routes.url_helpers
    attr_reader :params, :admin, :application, :constituent, :errors, :guardian_user_for_app

    def initialize(params:, admin:)
      super()
      # Use with_indifferent_access to handle both symbol and string keys
      @params = params.with_indifferent_access
      @admin = admin
      @application = nil
      @constituent = nil
      @guardian_user_for_app = nil # Initialize to nil
      @errors = []
    end

    def create
      Current.paper_context = true
      ActiveRecord::Base.transaction do
        return failure('Constituent processing failed') unless process_constituent
        return failure('Application creation failed') unless create_application
        return failure('Proof upload failed') unless process_proof_uploads

        handle_successful_application if @application.persisted?
        return @application.persisted?
      end
    rescue StandardError => e
      log_error(e, 'Failed to create paper application')
      @errors << e.message
      false
    ensure
      Current.paper_context = nil
    end

    def update(application)
      # Set the paper application context flag
      Current.paper_context = true
      Rails.logger.debug { "UPDATE: Set paper_application_context to #{Current.paper_context.inspect}" }

      begin
        ActiveRecord::Base.transaction do
          @application = application
          @constituent = application.user

          # Double-check the context is still set
          Rails.logger.debug do
            "UPDATE (before process_proof_uploads): paper_application_context is #{Current.paper_context.inspect}"
          end

          # The process_proof_uploads method also sets and clears the context, so we need to ensure
          # it's set correctly before and after the call
          result = process_proof_uploads

          # Re-set the context in case process_proof_uploads cleared it
          Current.paper_context = true
          Rails.logger.debug do
            "UPDATE (after process_proof_uploads): paper_application_context is #{Current.paper_context.inspect}"
          end

          return failure('Proof upload failed') unless result

          handle_successful_application if @application.persisted?
          return true
        end
      rescue StandardError => e
        log_error(e, 'Failed to update paper application')
        @errors << e.message
        false
      ensure
        # Always clear the Current attribute
        Rails.logger.debug { 'UPDATE (ensure): Clearing paper_application_context' }
        Current.paper_context = nil
      end
    end

    private

    def failure(message)
      @errors << message
      false
    end

    def handle_successful_application
      send_notifications
      log_application_creation
    end

    def log_application_creation
      Event.create!(
        user: @admin,
        action: 'application_created',
        metadata: {
          application_id: @application.id,
          submission_method: 'paper',
          initial_status: (@application.status || 'in_progress').to_s,
          timestamp: current_time.iso8601
        }
      )
    end

    def current_time
      @current_time ||= Time.current
    end

    def log_proof_debug_info(type)
      Rails.logger.debug { "==== PROCESS_PROOF(#{type}) STARTED ====" }
      Rails.logger.debug { "Params class: #{params.class.name}" }
      Rails.logger.debug { "Params keys: #{params.keys.inspect}" }
      Rails.logger.debug { "Param key as symbol: #{params[:"#{type}_proof_action"].inspect}" }
      Rails.logger.debug { "Param key as string: #{params["#{type}_proof_action"].inspect}" }
      Rails.logger.debug { "File param present? #{params["#{type}_proof"].present?}" }
      return if params["#{type}_proof"].blank?

      Rails.logger.debug { "File param type: #{params["#{type}_proof"].class.name}" }
      Rails.logger.debug { "File param details: #{params["#{type}_proof"].inspect}" }
    end

    def extract_proof_action(type)
      params["#{type}_proof_action"] || params[:"#{type}_proof_action"]
    end

    def process_accept_proof(type)
      Rails.logger.debug { "Accepting #{type} proof" }
      file_present = proof_file_present?(type)

      if Current.paper_context? && !file_present
        approve_proof_without_file(type)
      elsif file_present
        attach_and_approve_proof(type)
      else
        handle_missing_proof_file(type)
      end
    end

    def proof_file_present?(type)
      params["#{type}_proof"].present? || params["#{type}_proof_signed_id"].present?
    end

    def approve_proof_without_file(type)
      Rails.logger.debug { "Paper context: Marking #{type} proof as approved without file attachment." }

      update_proof_status(type, 'approved')
      log_paper_proof_submission(type)

      true
    end

    def attach_and_approve_proof(type)
      blob_or_file = params["#{type}_proof"].presence || params["#{type}_proof_signed_id"].presence

      result = ProofAttachmentService.attach_proof(
        application: @application,
        proof_type: type,
        blob_or_file: blob_or_file,
        status: :approved,
        admin: @admin,
        submission_method: :paper,
        metadata: {}
      )

      unless result[:success]
        add_error("Error processing #{type} proof: #{result[:error]&.message}")
        return false
      end

      update_proof_status(type, 'approved')
      Rails.logger.debug { "Successfully attached #{type} proof for application #{@application.id}" }
      true
    end

    def handle_missing_proof_file(type)
      Rails.logger.debug { "No file or signed_id provided for #{type} and not in paper context." }
      add_error("Please upload a file for #{type} proof")
      false
    end

    def update_proof_status(type, status)
      @application.update!(
        "#{type}_proof_status" => Application.public_send("#{type}_proof_statuses")[status]
      )
    end

    def log_paper_proof_submission(type)
      AuditEventService.log(
        action: 'proof_submitted',
        actor: @admin,
        auditable: @application,
        metadata: {
          proof_type: type.to_s,
          submission_method: 'paper',
          status: 'approved',
          has_attachment: false
        }
      )
    end

    def process_reject_proof(type)
      Rails.logger.debug { "Rejecting #{type} proof" }
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
      # Ensure a ProofReview record exists even if the service was stubbed
      @application.proof_reviews.reload
      create_proof_review(type, :rejected) if @application.proof_reviews.where(proof_type: type, status: :rejected).empty?
      Rails.logger.debug { "Successfully rejected #{type} proof" }
      true
    end

    def attributes_present?(attrs)
      attrs.present? && attrs.values.any?(&:present?)
    end

    def process_constituent
      guardian_id = params[:guardian_id]
      new_guardian_attrs = params[:new_guardian_attributes]
      applicant_data_for_constituent = params[:constituent]
      relationship_type = params[:relationship_type]

      if guardian_scenario?(guardian_id, new_guardian_attrs, applicant_data_for_constituent)
        process_guardian_scenario(guardian_id, new_guardian_attrs, applicant_data_for_constituent, relationship_type)
      elsif self_applicant_scenario?(applicant_data_for_constituent)
        process_self_applicant_scenario(applicant_data_for_constituent)
      else
        add_error('Sufficient constituent or guardian/dependent parameters missing or incomplete.')
        false
      end
    end

    def guardian_scenario?(guardian_id, new_guardian_attrs, applicant_data_for_constituent)
      (guardian_id.present? || attributes_present?(new_guardian_attrs)) &&
        attributes_present?(applicant_data_for_constituent) &&
        params[:applicant_type] == 'dependent'
    end

    def self_applicant_scenario?(applicant_data_for_constituent)
      attributes_present?(applicant_data_for_constituent) && params[:applicant_type] != 'dependent'
    end

    def process_guardian_scenario(guardian_id, new_guardian_attrs, applicant_data_for_constituent, relationship_type)
      return false unless setup_guardian_user(guardian_id, new_guardian_attrs)

      applicant_data_for_constituent = applicant_data_for_constituent.deep_dup
      log_guardian_scenario_debug(applicant_data_for_constituent)
      determine_dependent_contact_strategy(applicant_data_for_constituent)

      return false unless create_dependent_user(applicant_data_for_constituent)
      return false unless create_guardian_relationship(relationship_type)
      return false unless validate_no_active_application('dependent')

      true
    end

    def process_self_applicant_scenario(applicant_data_for_constituent)
      @constituent = find_or_create_user(applicant_data_for_constituent, is_managing_adult: false)
      return false unless @constituent&.persisted?

      @guardian_user_for_app = nil
      validate_no_active_application('constituent')
    end

    def setup_guardian_user(guardian_id, new_guardian_attrs)
      if guardian_id.present?
        @guardian_user_for_app = User.find_by(id: guardian_id)
        return add_error("Selected guardian with ID #{guardian_id} not found.") unless @guardian_user_for_app
      elsif attributes_present?(new_guardian_attrs)
        @guardian_user_for_app = find_or_create_user(new_guardian_attrs, is_managing_adult: true)
        return false unless @guardian_user_for_app&.persisted?
      else
        return add_error('Guardian information missing or incomplete for dependent application.')
      end
      true
    end

    def log_guardian_scenario_debug(applicant_data_for_constituent)
      Rails.logger.debug do
        '[PAPER_APP] Guardian email check, params: ' \
          "use_guardian_email=#{params[:use_guardian_email].inspect}, " \
          "use_guardian_address=#{params[:use_guardian_address].inspect}, " \
          "use_guardian_phone=#{params[:use_guardian_phone].inspect}"
      end
      Rails.logger.debug { "[PAPER_APP] Dependent email: #{applicant_data_for_constituent[:email].inspect}" }
      Rails.logger.debug { "[PAPER_APP] Dependent phone: #{applicant_data_for_constituent[:phone].inspect}" }
    end

    def create_dependent_user(applicant_data_for_constituent)
      @constituent = find_or_create_user(applicant_data_for_constituent, is_managing_adult: false)
      @constituent&.persisted?
    end

    def create_guardian_relationship(relationship_type)
      return add_error('Relationship type is required when applying for a dependent.') if relationship_type.blank?

      GuardianRelationship.create!(
        guardian_user: @guardian_user_for_app,
        dependent_user: @constituent,
        relationship_type: relationship_type
      )
      true
    rescue ActiveRecord::RecordInvalid => e
      add_error("Failed to create guardian relationship: #{e.message}")
      false
    end

    def validate_no_active_application(user_type)
      return true unless @constituent.applications.where.not(status: :archived).exists?

      error_message = case user_type
                      when 'dependent'
                        'This dependent already has an active or pending application.'
                      else
                        'This constituent already has an active or pending application.'
                      end
      add_error(error_message)
      false
    end

    def find_or_create_user(attrs, is_managing_adult:)
      Rails.logger.info { "[PAPER_APP] Finding or creating user: #{attrs.slice(:email, :first_name, :last_name).inspect}" }

      existing_user_lookup(attrs, is_managing_adult) || create_new_user(attrs, is_managing_adult: is_managing_adult)
    end

    def existing_user_lookup(attrs, is_managing_adult)
      is_dependent = !is_managing_adult && @guardian_user_for_app

      user = find_user_by_email(attrs, is_dependent) || find_user_by_phone(attrs, is_dependent)

      return user if user_valid_for_context?(user, is_dependent)

      validate_dependent_email_requirement(attrs, is_managing_adult) unless is_managing_adult
      nil
    end

    def find_user_by_email(attrs, _is_dependent)
      return nil unless attrs[:email].present? && attrs[:email].exclude?('@system.matvulcan.local')

      Rails.logger.info { "[PAPER_APP] Looking up user by email: #{attrs[:email]}" }
      User.find_by_email(attrs[:email])
    end

    def find_user_by_phone(attrs, _is_dependent)
      return nil if attrs[:phone].blank?

      formatted_phone = User.new(phone: attrs[:phone]).phone
      Rails.logger.info { "[PAPER_APP] Looking up user by phone: #{formatted_phone}" }
      User.find_by_phone(formatted_phone)
    end

    def user_valid_for_context?(user, is_dependent)
      return false unless user

      if is_dependent && user.id == @guardian_user_for_app&.id
        Rails.logger.warn { '[PAPER_APP] Found user that matches guardian ID. Will create new user instead.' }
        return false
      end

      Rails.logger.info { "[PAPER_APP] Found existing user: #{user.email}, id: #{user.id}" }
      true
    end

    def validate_dependent_email_requirement(attrs, is_managing_adult)
      return if is_managing_adult || attrs[:email].present?

      Rails.logger.error { "[PAPER_APP] CRITICAL: Attempting to create dependent without email: #{attrs.inspect}" }

      guardian_info = if @guardian_user_for_app
                        "Guardian info: #{@guardian_user_for_app.id}/#{@guardian_user_for_app.email}"
                      else
                        'No guardian selected'
                      end

      strategy_info = build_strategy_debug_info

      add_error("Cannot create dependent: Email is required. Please ensure either a dedicated email is provided for the dependent, or email strategy isset to 'guardian'. #{guardian_info}. Form params: #{strategy_info}")
    end

    def build_strategy_debug_info
      "email_strategy=#{params[:email_strategy].inspect}, " \
        "phone_strategy=#{params[:phone_strategy].inspect}, " \
        "address_strategy=#{params[:address_strategy].inspect}"
    end

    def create_new_user(attrs, is_managing_adult:)
      # For paper applications, disability selection is usually on the form for the applicant.
      # If this is a dependent, ensure_disability_selection should apply.
      # If it's a guardian being created, they don't need disability flags set.
      ensure_disability_selection(attrs) unless is_managing_adult

      # Remove any non-model attributes
      attrs.delete(:notification_method) if attrs.key?(:notification_method)
      attrs.delete('notification_method') if attrs.key?('notification_method')

      # Double-check that email is present for validation
      if attrs[:email].blank?
        error_context = is_managing_adult ? 'guardian' : 'dependent'
        Rails.logger.error { "[PAPER_APP] CRITICAL: Attempting to create #{error_context} with blank email. Attributes: #{attrs.inspect}" }
        return add_error("Failed to create #{error_context}: Email is required.")
      end

      temp_password = SecureRandom.hex(8)
      new_user = Users::Constituent.new(attrs) # Explicitly use Users::Constituent
      new_user.password = temp_password
      new_user.password_confirmation = temp_password
      new_user.verified = true
      new_user.force_password_change = true

      # STI type is handled by Users::Constituent.new

      Rails.logger.info do
        "[PAPER_APP] Creating new user with type: #{new_user.type}, email: #{attrs[:email]}, first_name: #{attrs[:first_name]}"
      end

      if new_user.save
        Rails.logger.info { "[PAPER_APP] Successfully created new user with ID: #{new_user.id}, email: #{new_user.email}" }
        @temp_password_for_new_user ||= {} # Store temp passwords if multiple users created
        @temp_password_for_new_user[new_user.id] = temp_password
        new_user
      else
        error_msg = "Failed to create user (#{attrs[:email] || attrs[:phone]}): #{new_user.errors.full_messages.join(', ')}"
        Rails.logger.error { "[PAPER_APP] #{error_msg}" }
        add_error(error_msg)
        nil
      end
    end

    def ensure_disability_selection(attrs)
      # This method is now primarily for the applicant (dependent or self-applicant)
      has_any_disability = %i[hearing_disability vision_disability speech_disability
                              mobility_disability cognition_disability].any? do |disability|
        ['1', true].include?(attrs[disability])
      end

      # Default to hearing disability if none are selected
      attrs[:hearing_disability] = '1' unless has_any_disability
    end

    def determine_dependent_contact_strategy(applicant_data_for_constituent)
      return unless @guardian_user_for_app

      apply_email_strategy(applicant_data_for_constituent)
      apply_phone_strategy(applicant_data_for_constituent)
      apply_address_strategy(applicant_data_for_constituent)
    end

    def apply_email_strategy(applicant_data)
      strategy = params[:email_strategy]

      case strategy
      when 'guardian'
        guardian_email_strategy(applicant_data)
      when 'dependent'
        dependent_email_strategy(applicant_data)
      else
        default_email_strategy(applicant_data)
      end
    end

    def apply_phone_strategy(applicant_data)
      strategy = params[:phone_strategy]

      case strategy
      when 'guardian'
        guardian_phone_strategy(applicant_data)
      when 'dependent'
        dependent_phone_strategy(applicant_data)
      else
        default_phone_strategy(applicant_data)
      end
    end

    def apply_address_strategy(applicant_data)
      if params[:address_strategy] == 'dependent'
        Rails.logger.info { '[PAPER_APP] Dependent will use their own address' }
      else
        copy_guardian_address(applicant_data)
      end
    end

    def guardian_email_strategy(applicant_data)
      Rails.logger.info { "[PAPER_APP] Dependent will share guardian's email (#{@guardian_user_for_app.email})" }
      applicant_data[:dependent_email] = @guardian_user_for_app.email
      applicant_data[:email] = generate_system_email
    end

    def dependent_email_strategy(applicant_data)
      if applicant_data[:dependent_email].present?
        Rails.logger.info { "[PAPER_APP] Dependent will use their own email (#{applicant_data[:dependent_email]})" }
        applicant_data[:email] = applicant_data[:dependent_email]
      else
        Rails.logger.warn { '[PAPER_APP] Email strategy is "dependent" but no dependent_email provided, falling back to guardian email' }
        guardian_email_strategy(applicant_data)
      end
    end

    def default_email_strategy(applicant_data)
      Rails.logger.info { '[PAPER_APP] No email strategy specified, defaulting to guardian email' }
      guardian_email_strategy(applicant_data)
    end

    def guardian_phone_strategy(applicant_data)
      Rails.logger.info { "[PAPER_APP] Dependent will share guardian's phone (#{@guardian_user_for_app.phone})" }
      applicant_data[:dependent_phone] = @guardian_user_for_app.phone
      applicant_data[:phone] = generate_system_phone
    end

    def dependent_phone_strategy(applicant_data)
      if applicant_data[:dependent_phone].present?
        Rails.logger.info { "[PAPER_APP] Dependent will use their own phone (#{applicant_data[:dependent_phone]})" }
        applicant_data[:phone] = applicant_data[:dependent_phone]
      else
        Rails.logger.warn { '[PAPER_APP] Phone strategy is "dependent" but no dependent_phone provided, falling back to guardian phone' }
        guardian_phone_strategy(applicant_data)
      end
    end

    def default_phone_strategy(applicant_data)
      Rails.logger.info { '[PAPER_APP] No phone strategy specified, defaulting to guardian phone' }
      guardian_phone_strategy(applicant_data)
    end

    def copy_guardian_address(applicant_data)
      Rails.logger.info { '[PAPER_APP] Dependent will use guardian address' }
      applicant_data[:physical_address_1] = @guardian_user_for_app.physical_address_1
      applicant_data[:physical_address_2] = @guardian_user_for_app.physical_address_2
      applicant_data[:city] = @guardian_user_for_app.city
      applicant_data[:state] = @guardian_user_for_app.state
      applicant_data[:zip_code] = @guardian_user_for_app.zip_code
    end

    def generate_system_email
      "dependent-#{SecureRandom.uuid}@system.matvulcan.local"
    end

    def generate_system_phone
      "000-000-#{rand(1000..9999)}"
    end

    def create_application
      # Set the paper application context flag
      Current.paper_context = true

      begin
        application_attrs = params[:application]
        return add_error('Application params missing') if application_attrs.blank?

        # Validate income thresholds
        unless income_within_threshold?(application_attrs[:household_size], application_attrs[:annual_income])
          return add_error('Income exceeds the maximum threshold for the household size.')
        end

        # Ensure constituent is fresh
        @constituent.reload

        # Build application with constituent association
        @application = Application.new(application_attrs) # Initialize without direct association first
        @application.user = @constituent # This is the applicant (dependent or self)
        @application.managing_guardian = @guardian_user_for_app # This will be nil if not a guardian scenario

        @application.submission_method = :paper
        @application.application_date = Time.current
        @application.status = :in_progress

        unless @application.save
          add_error("Failed to create application: #{@application.errors.full_messages.join(', ')}")
          return false
        end

        true
      ensure
        # Always clear the Current attribute
        Current.paper_context = nil
      end
    end

    def process_proof_uploads
      # Set paper application context again
      Current.paper_context = true

      # Enhanced debugging
      Rails.logger.debug '==== PAPER APPLICATION PROOF UPLOAD STARTED ===='
      Rails.logger.debug { "Current params: #{params.inspect}" }

      begin
        # Process income proof
        Rails.logger.debug 'About to process income proof'
        income_result = process_proof(:income)
        Rails.logger.debug { "Income proof processing result: #{income_result}" }
        return false unless income_result # Stop if income proof processing failed

        # Process residency proof
        Rails.logger.debug 'About to process residency proof'
        residency_result = process_proof(:residency)
        Rails.logger.debug { "Residency proof processing result: #{residency_result}" }
        return false unless residency_result # Stop if residency proof processing failed

        # Return true only if both succeeded
        Rails.logger.debug '==== PAPER APPLICATION PROOF UPLOAD FINISHED ===='
        true
      ensure
        # Always clear the Current attribute
        Current.paper_context = nil
      end
    end

    def process_proof(type)
      log_proof_debug_info(type)
      action = extract_proof_action(type)
      Rails.logger.debug { "Action determined: #{action.inspect}" }

      unless %w[accept reject].include?(action)
        Rails.logger.debug { "No valid action for #{type}, returning true" }
        return true
      end

      result = case action
               when 'accept'
                 process_accept_proof(type)
               when 'reject'
                 process_reject_proof(type)
               end

      Rails.logger.debug { "==== PROCESS_PROOF(#{type}) COMPLETED SUCCESSFULLY ====" }
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
      send_proof_rejection_notifications
      send_account_creation_notifications
    end

    def send_proof_rejection_notifications
      @application.proof_reviews.reload.each do |review|
        next unless review.status_rejected?

        send_notification_by_preference(
          type: :proof_rejected,
          recipient: @constituent,
          notifiable: review,
          template_name: 'application_notifications_proof_rejected',
          template_variables: proof_rejection_template_variables(review)
        )
      end
    end

    def send_account_creation_notifications
      new_user_accounts.each do |user_account|
        temp_password = @temp_password_for_new_user[user_account.id]
        ensure_user_password(user_account, temp_password)

        send_notification_by_preference(
          type: :account_created,
          recipient: user_account,
          notifiable: @application,
          template_name: 'application_notifications_account_created',
          template_variables: account_creation_template_variables(user_account, temp_password),
          temp_password: temp_password
        )
      end
    end

    def send_notification_by_preference(type:, recipient:, notifiable:, template_name:, template_variables:, temp_password: nil)
      if recipient.communication_preference == 'email'
        send_email_notification(type, recipient, notifiable, temp_password)
      else
        send_letter_notification(template_name, recipient, template_variables)
      end
    end

    def send_email_notification(type, recipient, notifiable, temp_password = nil)
      case type
      when :proof_rejected
        # The `proof_rejected` mailer expects `application` and `proof_review`
        ApplicationNotificationsMailer.proof_rejected(@application, notifiable).deliver_later
      when :account_created
        # The `account_created` mailer expects `constituent` and `temp_password`
        ApplicationNotificationsMailer.account_created(recipient, temp_password).deliver_later
      else
        Rails.logger.warn "PaperApplicationService: No mailer action configured for type '#{type}'"
      end
    end

    def send_letter_notification(template_name, recipient, variables)
      Letters::TextTemplateToPdfService.new(
        template_name: template_name,
        recipient: recipient,
        variables: variables
      ).queue_for_printing
    end

    def new_user_accounts
      [@guardian_user_for_app, @constituent].compact.uniq.select do |user_account|
        recently_created?(user_account) && temp_password?(user_account)
      end
    end

    def recently_created?(user_account)
      user_account.present? && user_account.created_at >= 5.minutes.ago
    end

    def temp_password?(user_account)
      @temp_password_for_new_user&.key?(user_account.id)
    end

    def ensure_user_password(user_account, temp_password)
      return if user_account.password_digest.present?

      user_account.update(password: temp_password, password_confirmation: temp_password)
    end

    def account_creation_template_variables(user_account, temp_password)
      {
        constituent_first_name: user_account.first_name,
        constituent_email: user_account.email,
        temp_password: temp_password,
        sign_in_url: sign_in_url(host: Rails.application.config.action_mailer.default_url_options[:host])
      }
    end

    def proof_rejection_template_variables(review)
      {
        constituent_full_name: @constituent.full_name,
        organization_name: Policy.get('organization_name') || 'MAT Program',
        proof_type_formatted: review.proof_type.humanize,
        rejection_reason: review.rejection_reason || 'Document did not meet requirements'
      }
    end

    def income_within_threshold?(household_size, annual_income)
      Rails.logger.debug { "Checking income threshold: household_size=#{household_size}, annual_income=#{annual_income}" }
      return false unless household_size.present? && annual_income.present?

      hs_int = household_size.to_i
      policy_key = "fpl_#{[hs_int, 8].min}_person"
      base_fpl = Policy.get(policy_key).to_i
      Rails.logger.debug { "Policy key: #{policy_key}, Base FPL: #{base_fpl}" }

      modifier = Policy.get('fpl_modifier_percentage').to_i
      Rails.logger.debug { "Modifier: #{modifier}" }

      threshold = base_fpl * (modifier / 100.0)
      Rails.logger.debug { "Calculated threshold: #{threshold}" }

      income_float = annual_income.to_f
      Rails.logger.debug { "Income float: #{income_float}" }

      result = income_float <= threshold
      Rails.logger.debug { "Income within threshold? #{result}" }
      result
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
