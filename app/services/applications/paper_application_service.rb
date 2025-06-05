# frozen_string_literal: true

module Applications
  # This service handles paper application submissions by administrators
  # It follows the same patterns as ConstituentPortal for file uploads
  class PaperApplicationService < BaseService
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
    end

    def update(application)
      # Set the paper application context flag
      Thread.current[:paper_application_context] = true
      Rails.logger.debug { "UPDATE: Set paper_application_context to #{Thread.current[:paper_application_context].inspect}" }

      begin
        ActiveRecord::Base.transaction do
          @application = application
          @constituent = application.user

          # Double-check the context is still set
          Rails.logger.debug do
            "UPDATE (before process_proof_uploads): paper_application_context is #{Thread.current[:paper_application_context].inspect}"
          end

          # The process_proof_uploads method also sets and clears the context, so we need to ensure
          # it's set correctly before and after the call
          result = process_proof_uploads

          # Re-set the context in case process_proof_uploads cleared it
          Thread.current[:paper_application_context] = true
          Rails.logger.debug do
            "UPDATE (after process_proof_uploads): paper_application_context is #{Thread.current[:paper_application_context].inspect}"
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
        # Always clear the thread-local variable
        Rails.logger.debug { 'UPDATE (ensure): Clearing paper_application_context' }
        Thread.current[:paper_application_context] = nil
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
      log_proof_submission_audit
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

    def log_proof_submission_audit
      ProofSubmissionAudit.create!(
        application_id: @application.id,
        user_id: @admin.id,
        proof_type: 'application',
        ip_address: '0.0.0.0',
        metadata: {
          submission_method: 'paper',
          timestamp: current_time.iso8601,
          action: 'submit'
        },
        submission_method: :paper,
        created_at: current_time,
        updated_at: current_time
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
      return unless params["#{type}_proof"].present?

      Rails.logger.debug { "File param type: #{params["#{type}_proof"].class.name}" }
      Rails.logger.debug { "File param details: #{params["#{type}_proof"].inspect}" }
    end

    def extract_proof_action(type)
      params["#{type}_proof_action"] || params[:"#{type}_proof_action"]
    end

    def process_accept_proof(type)
      Rails.logger.debug { "Accepting #{type} proof" }

      # Determine if a file is being uploaded
      file_present = params["#{type}_proof"].present? || params["#{type}_proof_signed_id"].present?

      if Thread.current[:paper_application_context] && !file_present
        # Scenario: Paper application where admin is marking proof as accepted without a digital upload
        Rails.logger.debug { "Paper context: Marking #{type} proof as approved without file attachment." }
        @application.update_column(
          "#{type}_proof_status",
          Application.public_send("#{type}_proof_statuses")['approved']
        )
        true
      elsif file_present
        # Scenario: Digital upload or paper application with a digital upload
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

        # Persist approved status for paper applications, including when attach_proof is stubbed
        @application.update_column(
          "#{type}_proof_status",
          Application.public_send("#{type}_proof_statuses")['approved']
        )
        Rails.logger.debug { "Successfully attached #{type} proof for application #{@application.id}" }
        true
      else
        # Fallback for non-paper context or if no file is provided when expected
        Rails.logger.debug { "No file or signed_id provided for #{type} and not in paper context." }
        add_error("Please upload a file for #{type} proof")
        false
      end
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
      # new_guardian_attributes are passed by the controller if a new guardian is to be created
      new_guardian_attrs = params[:new_guardian_attributes]
      # The controller now maps dependent_attributes into params[:constituent] for guardian scenarios
      # and self-applicant attributes also into params[:constituent] for self-applications.
      applicant_data_for_constituent = params[:constituent]
      relationship_type = params[:relationship_type]
      


      # Determine if this is a guardian scenario
      # It's a guardian scenario if a guardian_id is provided OR new_guardian_attributes are provided,
      # AND applicant_data_for_constituent (which holds dependent data in this case) is present.
      is_guardian_scenario = (guardian_id.present? || attributes_present?(new_guardian_attrs)) &&
                             attributes_present?(applicant_data_for_constituent) &&
                             params[:applicant_type] == 'dependent' # Explicitly check applicant_type

      if is_guardian_scenario
        # Scenario: Guardian applying for a dependent
        if guardian_id.present?
          @guardian_user_for_app = User.find_by(id: guardian_id)
          return add_error("Selected guardian with ID #{guardian_id} not found.") unless @guardian_user_for_app
        elsif attributes_present?(new_guardian_attrs)
          @guardian_user_for_app = find_or_create_user(new_guardian_attrs, is_managing_adult: true)
          return false unless @guardian_user_for_app&.persisted?
        else
          # This path should ideally not be reached if controller logic is correct
          return add_error('Guardian information missing or incomplete for dependent application.')
        end

        # Make a deep copy of the hash to avoid modifying the original object
        applicant_data_for_constituent = applicant_data_for_constituent.deep_dup

        # Check if we should use guardian's email for dependent
        # Support both parameter names for backward compatibility:
        # - use_guardian_email: New explicit parameter name
        # - use_guardian_address: Legacy parameter name that also implies using guardian's email

        # Debug the parameters to understand how they're coming through
        Rails.logger.debug do
          "[PAPER_APP] Guardian email check, params: use_guardian_email=#{params[:use_guardian_email].inspect}, use_guardian_address=#{params[:use_guardian_address].inspect}, use_guardian_phone=#{params[:use_guardian_phone].inspect}"
        end
        Rails.logger.debug { "[PAPER_APP] Dependent email value in form: #{applicant_data_for_constituent[:email].inspect}" }
        Rails.logger.debug { "[PAPER_APP] Dependent phone value in form: #{applicant_data_for_constituent[:phone].inspect}" }

        # Handle contact strategy for dependent using new radio button approach
        determine_dependent_contact_strategy(applicant_data_for_constituent)

        # Process dependent (the actual applicant) using applicant_data_for_constituent
        @constituent = find_or_create_user(applicant_data_for_constituent, is_managing_adult: false)
        return false unless @constituent&.persisted?

        # Create GuardianRelationship
        return add_error('Relationship type is required when applying for a dependent.') if relationship_type.blank?

        begin
          GuardianRelationship.create!(
            guardian_user: @guardian_user_for_app,
            dependent_user: @constituent,
            relationship_type: relationship_type
          )
        rescue ActiveRecord::RecordInvalid => e
          return add_error("Failed to create guardian relationship: #{e.message}")
        end

        # Check for active application on the dependent
        if @constituent.applications.where.not(status: :archived).exists?
          add_error('This dependent already has an active or pending application.')
          return false
        end

      elsif attributes_present?(applicant_data_for_constituent) && params[:applicant_type] != 'dependent'
        # Scenario: Adult applying for themselves (applicant_type is 'guardian' or nil/other)
        @constituent = find_or_create_user(applicant_data_for_constituent, is_managing_adult: false)
        return false unless @constituent&.persisted?

        # Check for active application
        if @constituent.applications.where.not(status: :archived).exists?
          add_error('This constituent already has an active or pending application.')
          return false
        end
        @guardian_user_for_app = nil # Explicitly nil for self-applicants
      else
        # Neither a valid guardian scenario nor a valid self-applicant scenario.
        return add_error('Sufficient constituent or guardian/dependent parameters missing or incomplete.')
      end
      true # If all checks pass
    end

    def find_or_create_user(attrs, is_managing_adult:)
      user = nil
      # Enhanced logging for debugging
      Rails.logger.info { "[PAPER_APP] Finding or creating user with attributes: #{attrs.slice(:email, :first_name, :last_name).inspect}" }

      # If this is a dependent, check if it's using guardian's contact info
      is_dependent = !is_managing_adult && @guardian_user_for_app

      # For dependents, we now use system-generated emails/phones so no uniqueness conflicts
      # Try to find existing user first (but skip for dependents with system emails)
      if attrs[:email].present? && !attrs[:email].include?('@system.matvulcan.local')
        # Not a dependent using guardian's contact info, so try to find an existing user
        Rails.logger.info { "[PAPER_APP] Looking up user by email: #{attrs[:email]}" }
        user = User.find_by_email(attrs[:email])
        if user
          # Never return the guardian as a dependent
          if is_dependent && user.id == @guardian_user_for_app&.id
            Rails.logger.warn { '[PAPER_APP] Found user that matches guardian ID. Will create new user instead.' }
          else
            Rails.logger.info { "[PAPER_APP] Found existing user with email: #{user.email}, id: #{user.id}" }
            return user # Return existing user that isn't the guardian
          end
        end
      elsif attrs[:phone].present?
        # Ensure phone is formatted for lookup if needed
        formatted_phone = User.new(phone: attrs[:phone]).phone # Use formatted phone for lookup
        Rails.logger.info { "[PAPER_APP] Looking up user by phone: #{formatted_phone}" }
        user = User.find_by_phone(formatted_phone)
        if user
          # Never return the guardian as a dependent
          if is_dependent && user.id == @guardian_user_for_app&.id
            Rails.logger.warn { '[PAPER_APP] Found user with same phone as guardian. Will create new user instead.' }
          else
            Rails.logger.info { "[PAPER_APP] Found existing user with phone: #{user.phone}, id: #{user.id}" }
            return user # Return existing user that isn't the guardian
          end
        end
      end

      # If we're creating a dependent and there's no email, this is a critical error
      # that would fail validation - add better debugging and error messages
      if !is_managing_adult && attrs[:email].blank?
        Rails.logger.error { "[PAPER_APP] CRITICAL: Attempting to create dependent without email. Full attributes: #{attrs.inspect}" }
        # Include more helpful messaging for the error
        guardian_info = @guardian_user_for_app ? "Guardian info: #{@guardian_user_for_app.id}/#{@guardian_user_for_app.email}" : 'No guardian selected'
        strategy_info = "email_strategy=#{params[:email_strategy].inspect}, phone_strategy=#{params[:phone_strategy].inspect}, address_strategy=#{params[:address_strategy].inspect}"
        add_error("Cannot create dependent: Email is required. Please ensure either a dedicated email is provided for the dependent, or email strategy is set to 'guardian'. #{guardian_info}. Form params: #{strategy_info}")
        return nil
      end

      # Create new user if not found
      create_new_user(attrs, is_managing_adult: is_managing_adult)
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

      # Handle email strategy
      case params[:email_strategy]
      when 'guardian'
        # Dependent shares guardian's email
        Rails.logger.info { "[PAPER_APP] Dependent will share guardian's email (#{@guardian_user_for_app.email})" }
        applicant_data_for_constituent[:dependent_email] = @guardian_user_for_app.email
        applicant_data_for_constituent[:email] = "dependent-#{SecureRandom.uuid}@system.matvulcan.local"
      when 'dependent'
        # Dependent has their own email
        if applicant_data_for_constituent[:dependent_email].present?
          Rails.logger.info { "[PAPER_APP] Dependent will use their own email (#{applicant_data_for_constituent[:dependent_email]})" }
          applicant_data_for_constituent[:email] = applicant_data_for_constituent[:dependent_email]
        else
          Rails.logger.warn { '[PAPER_APP] Email strategy is "dependent" but no dependent_email provided, falling back to guardian email' }
          # Fall back to guardian's email when dependent_email is blank
          applicant_data_for_constituent[:dependent_email] = @guardian_user_for_app.email
          applicant_data_for_constituent[:email] = "dependent-#{SecureRandom.uuid}@system.matvulcan.local"
        end
      else
        # Default to guardian's email if no strategy specified
        Rails.logger.info { '[PAPER_APP] No email strategy specified, defaulting to guardian email' }
        applicant_data_for_constituent[:dependent_email] = @guardian_user_for_app.email
        applicant_data_for_constituent[:email] = "dependent-#{SecureRandom.uuid}@system.matvulcan.local"
      end

      # Handle phone strategy  
      case params[:phone_strategy]
      when 'guardian'
        # Dependent shares guardian's phone
        Rails.logger.info { "[PAPER_APP] Dependent will share guardian's phone (#{@guardian_user_for_app.phone})" }
        applicant_data_for_constituent[:dependent_phone] = @guardian_user_for_app.phone
        applicant_data_for_constituent[:phone] = "000-000-#{rand(1000..9999)}"
      when 'dependent'
        # Dependent has their own phone
        if applicant_data_for_constituent[:dependent_phone].present?
          Rails.logger.info { "[PAPER_APP] Dependent will use their own phone (#{applicant_data_for_constituent[:dependent_phone]})" }
          applicant_data_for_constituent[:phone] = applicant_data_for_constituent[:dependent_phone]
        else
          Rails.logger.warn { '[PAPER_APP] Phone strategy is "dependent" but no dependent_phone provided, falling back to guardian phone' }
          # Fall back to guardian's phone when dependent_phone is blank
          applicant_data_for_constituent[:dependent_phone] = @guardian_user_for_app.phone
          applicant_data_for_constituent[:phone] = "000-000-#{rand(1000..9999)}"
        end
      else
        # Default to guardian's phone if no strategy specified
        Rails.logger.info { '[PAPER_APP] No phone strategy specified, defaulting to guardian phone' }
        applicant_data_for_constituent[:dependent_phone] = @guardian_user_for_app.phone
        applicant_data_for_constituent[:phone] = "000-000-#{rand(1000..9999)}"
      end

      # Handle address strategy (optional - defaults to guardian's address)
      case params[:address_strategy]
      when 'dependent'
        # Dependent has their own address - no action needed, use provided address fields
        Rails.logger.info { '[PAPER_APP] Dependent will use their own address' }
      else
        # Default to guardian's address - copy from guardian
        Rails.logger.info { '[PAPER_APP] Dependent will use guardian address' }
        applicant_data_for_constituent[:physical_address_1] = @guardian_user_for_app.physical_address_1
        applicant_data_for_constituent[:physical_address_2] = @guardian_user_for_app.physical_address_2
        applicant_data_for_constituent[:city] = @guardian_user_for_app.city
        applicant_data_for_constituent[:state] = @guardian_user_for_app.state
        applicant_data_for_constituent[:zip_code] = @guardian_user_for_app.zip_code
      end
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
        # Always clear the thread-local variable
        Thread.current[:paper_application_context] = nil
      end
    end

    def process_proof_uploads
      # Set paper application context again
      Thread.current[:paper_application_context] = true

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
        # Always clear the thread-local variable
        Thread.current[:paper_application_context] = nil
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
      if @constituent.communication_preference == 'email'
        # Send emails as before
        @application.proof_reviews.reload.each do |review|
          ApplicationNotificationsMailer.proof_rejected(@application, review).deliver_later if review.status_rejected?
        end

        # Send account creation email for new constituents
        # Handle multiple new users (guardian and/or dependent)
        [@guardian_user_for_app, @constituent].compact.uniq.each do |user_account|
          next unless user_account.created_at >= 5.minutes.ago && @temp_password_for_new_user&.key?(user_account.id)

          temp_password = @temp_password_for_new_user[user_account.id]
          # User might have been created without password if found by email/phone, ensure it's set if new
          user_account.update(password: temp_password, password_confirmation: temp_password) if user_account.password_digest.blank?
          ApplicationNotificationsMailer.account_created(user_account, temp_password).deliver_later
        end
      else
        # Generate letters for printing instead
        [@guardian_user_for_app, @constituent].compact.uniq.each do |user_account|
          next unless user_account.created_at >= 5.minutes.ago && @temp_password_for_new_user&.key?(user_account.id)

          temp_password = @temp_password_for_new_user[user_account.id]
          user_account.update(password: temp_password, password_confirmation: temp_password) if user_account.password_digest.blank?

          Letters::TextTemplateToPdfService.new(
            template_name: 'application_notifications_account_created',
            recipient: user_account,
            variables: {
              constituent_first_name: user_account.first_name,
              constituent_email: user_account.email, # This might be blank for paper apps
              temp_password: temp_password, # Make sure this is available
              sign_in_url: new_session_url, # Assuming new_session_url helper exists
              # Shared partial variables for text template
              header_text: Mailers::SharedPartialHelpers.header_text(
                title: 'Your Maryland Accessible Telecommunications Account',
                logo_url: ActionController::Base.helpers.asset_path('logo.png',
                                                                    host: Rails.application.config.action_mailer.default_url_options[:host])
              ),
              footer_text: Mailers::SharedPartialHelpers.footer_text(
                contact_email: Policy.get('support_email') || 'support@example.com',
                website_url: root_url(host: Rails.application.config.action_mailer.default_url_options[:host]),
                show_automated_message: true
              )
            }
          ).queue_for_printing
        end

        # Proof rejection letters using  TextTemplateToPdfService with database templates
        @application.proof_reviews.reload.each do |review|
          next unless review.status_rejected?

          Letters::TextTemplateToPdfService.new(
            template_name: 'application_notifications_proof_rejected',
            recipient: @constituent,
            variables: {
              constituent_full_name: @constituent.full_name, # Assuming User model has a full_name method
              organization_name: Policy.get('organization_name') || 'MAT Program', # Use Policy for organization name
              proof_type_formatted: review.proof_type.humanize,
              rejection_reason: review.rejection_reason || 'Document did not meet requirements',
              # Shared partial variables for text template
              header_text: Mailers::SharedPartialHelpers.header_text(
                title: 'Document Verification Follow-up Required',
                logo_url: ActionController::Base.helpers.asset_path('logo.png',
                                                                    host: Rails.application.config.action_mailer.default_url_options[:host])
              ),
              footer_text: Mailers::SharedPartialHelpers.footer_text(
                contact_email: Policy.get('support_email') || 'support@example.com',
                website_url: root_url(host: Rails.application.config.action_mailer.default_url_options[:host]),
                show_automated_message: true
              )
              # Omitting optional variables for now
            }
          ).queue_for_printing
        end
      end
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
