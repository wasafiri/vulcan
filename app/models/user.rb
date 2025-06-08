# frozen_string_literal: true

require 'bcrypt'

# User model that serves as the base class for all user types in the system
class User < ApplicationRecord
  # Token generation for email verification and password reset
  generates_token_for :password_reset, expires_in: 20.minutes
  generates_token_for :email_verification, expires_in: 1.day

  # Ensure duplicate review flag is accessible
  attr_accessor :needs_duplicate_review unless column_names.include?('needs_duplicate_review')

  # Class methods
  def self.system_user
    @system_user ||= begin
      # Try to find using our encrypted helper method
      user = find_by_email('system@example.com')

      # If user exists but isn't admin type, update it
      user.update!(type: 'Users::Administrator') if user && !user.admin?

      # Create if not found
      if user.nil?
        user = User.create!(
          first_name: 'System',
          last_name: 'User',
          email: 'system@example.com',
          password: SecureRandom.hex(32),
          type: 'Users::Administrator',
          verified: true
        )
      end

      user
    end
  end

  # Rails 8 encryption helper methods for encrypted queries
  def self.find_by_email(email_value)
    return nil if email_value.blank?

    # With transparent encryption, we can use regular find_by
    User.find_by(email: email_value)
  rescue StandardError => e
    Rails.logger.warn "find_by_email failed: #{e.message}"
    nil
  end

  def self.find_by_phone(phone_value)
    return nil if phone_value.blank?

    User.find_by(phone: phone_value)
  rescue StandardError => e
    Rails.logger.warn "find_by_phone failed: #{e.message}"
    nil
  end

  def self.exists_with_email?(email_value, excluding_id: nil)
    return false if email_value.blank?

    query = User.where(email: email_value)
    query = query.where.not(id: excluding_id) if excluding_id
    query.exists?
  rescue StandardError => e
    Rails.logger.warn "exists_with_email? failed: #{e.message}"
    false
  end

  def self.exists_with_phone?(phone_value, excluding_id: nil)
    return false if phone_value.blank?

    query = User.where(phone: phone_value)
    query = query.where.not(id: excluding_id) if excluding_id
    query.exists?
  rescue StandardError => e
    Rails.logger.warn "exists_with_phone? failed: #{e.message}"
    false
  end

  def self.digest(string)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
    BCrypt::Password.create(string, cost: cost)
  end

  has_secure_password

  # Constants
  MAX_LOGIN_ATTEMPTS = 5
  PASSWORD_RESET_EXPIRY = 20.minutes
  LOCK_DURATION = 1.hour
  VALID_ROLES = %w[admin constituent evaluator vendor trainer].freeze

  # Callbacks
  # Format phone numbers before validation to ensure uniqueness check uses the correct format
  before_validation :format_phone_number
  before_save :format_phone_number, if: :phone_changed?
  after_update :log_profile_changes, if: :saved_changes_to_profile_fields?
  after_save :reset_all_caches

  # Associations
  has_many :sessions, dependent: :destroy
  has_many :events, dependent: :destroy # Added for audit trail
  has_many :received_notifications,
           class_name: 'Notification',
           foreign_key: :recipient_id,
           dependent: :destroy
  has_many :applications, inverse_of: :user # Add inverse_of here too for consistency
  has_many :income_verified_applications, # Add the missing inverse association
           class_name: 'Application',
           foreign_key: :income_verified_by_id,
           inverse_of: :income_verified_by,
           dependent: :nullify
  has_many :role_capabilities, dependent: :destroy

  # Guardian/Dependent Associations
  has_many :guardian_relationships_as_guardian,
           class_name: 'GuardianRelationship',
           foreign_key: 'guardian_id',
           dependent: :destroy,
           inverse_of: :guardian_user
  has_many :dependents, through: :guardian_relationships_as_guardian, source: :dependent_user

  has_many :guardian_relationships_as_dependent,
           class_name: 'GuardianRelationship',
           foreign_key: 'dependent_id',
           dependent: :destroy,
           inverse_of: :dependent_user
  has_many :guardians, through: :guardian_relationships_as_dependent, source: :guardian_user

  has_many :managed_applications, # Applications where this user is the managing_guardian
           class_name: 'Application',
           foreign_key: 'managing_guardian_id',
           inverse_of: :managing_guardian,
           dependent: :nullify # Or :restrict_with_error if a guardian shouldn't be deleted if they manage apps

  has_and_belongs_to_many :products,
                          join_table: 'products_users'

  # Two-Factor Authentication Associations
  has_many :webauthn_credentials, dependent: :destroy
  has_many :totp_credentials, dependent: :destroy
  has_many :sms_credentials, dependent: :destroy

  # PII Encryption - Deterministic encryption for queryable fields
  # Rails 8 automatically maps to {attribute}_encrypted columns
  encrypts :email, deterministic: true
  encrypts :phone, deterministic: true
  encrypts :dependent_email, deterministic: true
  encrypts :dependent_phone, deterministic: true
  encrypts :ssn_last4, deterministic: true

  # Non-deterministic encryption for non-queryable fields
  encrypts :password_digest
  encrypts :date_of_birth
  encrypts :physical_address_1
  encrypts :physical_address_2
  encrypts :city
  encrypts :state
  encrypts :zip_code



  # Validations
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :first_name, presence: true, length: { maximum: 50 }
  validates :last_name, presence: true, length: { maximum: 50 }
  validates :middle_initial, length: { maximum: 1 }, allow_blank: true

  # Email and phone validations - relying on database constraints for uniqueness
  validates :email, presence: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :dependent_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :reset_password_token, uniqueness: true, allow_nil: true

  # Custom validations (uniqueness handled by database constraints)
  validate :email_must_be_unique
  validate :phone_must_be_unique
  validate :phone_number_must_be_valid, if: :phone_changed?
  validate :dependent_phone_number_must_be_valid, if: :dependent_phone_changed?
  validate :constituent_must_have_disability, if: :validate_constituent_disability?
  validate :validate_address_for_letter_preference

  # Status enum
  enum :status, { inactive: 0, active: 1, suspended: 2 }, default: :active

  # Communication preference enum
  enum :communication_preference, { email: 0, letter: 1 }, default: :email

  # Phone type enum
  enum :phone_type, { voice: 'voice', videophone: 'videophone', text: 'text' }, default: :voice

  # Callbacks
  after_save :log_profile_changes, if: :saved_changes_to_profile_fields?

  # Class methods for capabilities
  def self.capable_types_for(capability)
    case capability
    when 'can_train'
      %w[Users::Administrator Users::Trainer]
    when 'can_evaluate'
      %w[Users::Administrator Users::Evaluator]
    else
      []
    end
  end

  # Scopes
  scope :admins, -> { where(type: 'Users::Administrator') }
  scope :vendors, -> { where(type: 'Users::Vendor') }
  scope :ordered_by_name, -> { order(:first_name) }

  # Guardian relationship scopes
  scope :with_dependents, lambda {
    joins(:guardian_relationships_as_guardian).distinct
  }

  scope :with_guardians, lambda {
    joins(:guardian_relationships_as_dependent).distinct
  }

  # Basic user information
  def full_name
    [first_name, last_name].compact.join(' ')
  end

  # Override date_of_birth getter to handle encrypted string conversion
  def date_of_birth
    raw_value = super
    return nil if raw_value.blank?
    
    # If it's already a Date object, return it
    return raw_value if raw_value.is_a?(Date)
    
    # If it's a string (from encryption), parse it back to Date
    begin
      Date.parse(raw_value.to_s)
    rescue ArgumentError
      Rails.logger.warn "Invalid date format for user #{id}: #{raw_value}"
      nil
    end
  end

  # Role methods - detect based on class or type values to handle namespaced and non-namespaced types
  VALID_ROLES.each do |role|
    define_method "#{role}?" do
      if role == 'admin'
        # Special case for admin since we use Administrator as the class name
        self.class == Users::Administrator ||
          type == 'Administrator' ||
          type == 'Users::Administrator'
      else
        # Check for both namespaced and non-namespaced type values
        self.class.name == "Users::#{role.classify}" ||
          type == "Users::#{role.classify}" ||
          type == role.classify
      end
    end
  end

  # Method to return a list of disabilities
  def disabilities
    disability_list = []
    disability_list << 'Hearing Disability' if hearing_disability
    disability_list << 'Vision Disability' if vision_disability
    disability_list << 'Speech Disability' if speech_disability
    disability_list << 'Mobility Disability' if mobility_disability
    disability_list << 'Cognition Disability' if cognition_disability
    disability_list
  end

  def role_type
    type.to_s.underscore.humanize
  end

  def inherent_capabilities
    role_capabilities.pluck(:capability)
  end

  # Authentication methods
  def track_sign_in!(ip)
    if failed_attempts.to_i >= MAX_LOGIN_ATTEMPTS
      lock_account!
      return false
    end

    update(
      last_sign_in_at: Time.current,
      last_sign_in_ip: ip,
      failed_attempts: 0,
      locked_at: nil
    )
  end

  def lock_account!
    update!(locked_at: Time.current)
  end

  # Password reset methods
  def generate_password_reset_token!
    update(
      reset_password_token: SecureRandom.urlsafe_base64,
      reset_password_sent_at: Time.current
    )
  end

  def available_capabilities
    RoleCapability::CAPABILITIES
  end

  def has_capability?(capability)
    role_capabilities.exists?(capability: capability)
  end

  def prevent_self_role_update(current_user, new_role)
    !(self == current_user && type != new_role)
  end

  def add_capability(capability)
    return true if has_capability?(capability)

    new_capability = role_capabilities.new(capability: capability)
    if new_capability.save
      Rails.logger.info "Successfully added capability #{capability} to user #{id}"
      reset_all_caches
    else
      Rails.logger.error "Failed to add capability #{capability} to user #{id}: #{new_capability.errors.full_messages}"
    end
    new_capability
  end

  def remove_capability(capability)
    return true unless has_capability?(capability)

    role_capabilities.find_by(capability: capability)&.destroy
  end

  # Check if any second factor is enabled
  def second_factor_enabled?
    webauthn_credentials.exists? ||
      totp_credentials.exists? ||
      sms_credentials.exists?
  end

  def disability_selected?
    # Check if at least one disability is selected using a more explicit check
    disability_flags = [
      hearing_disability, vision_disability, speech_disability,
      mobility_disability, cognition_disability
    ]
    disability_flags.any? { |flag| flag == true }
  end

  # New guardian/dependent helper methods
  def is_guardian?
    guardian_relationships_as_guardian.exists?
  end

  def is_dependent?
    guardian_relationships_as_dependent.exists?
  end

  # Returns all applications for dependents of this guardian user
  def dependent_applications
    return Application.none unless is_guardian?

    Application.where(user_id: dependents.pluck(:id))
  end

  # Returns relationship types for a specific dependent
  def relationship_types_for_dependent(dependent_user)
    guardian_relationships_as_guardian
      .where(dependent_id: dependent_user.id)
      .pluck(:relationship_type)
  end

  # Helper methods for dependent contact information
  # These methods determine the effective contact information for a dependent
  # using dependent-specific contact info if available, otherwise falling back to guardian

  def effective_email
    if is_dependent? && dependent_email.present?
      dependent_email
    elsif is_dependent? && guardian_for_contact
      guardian_for_contact.email
    else
      email
    end
  end

  def effective_phone
    if is_dependent? && dependent_phone.present?
      dependent_phone
    elsif is_dependent? && guardian_for_contact
      guardian_for_contact.phone
    else
      phone
    end
  end

  def effective_phone_type
    if is_dependent? && dependent_phone.present?
      phone_type # Use dependent's preferred phone type
    elsif is_dependent? && guardian_for_contact
      guardian_for_contact.phone_type
    end

    phone_type
  end

  def effective_communication_preference
    if is_dependent? && guardian_for_contact
      guardian_for_contact.communication_preference
    else
      communication_preference
    end
  end
  
  # Get the primary guardian for contact purposes
  def guardian_for_contact
    return nil unless is_dependent?
    
    @guardian_for_contact ||= guardian_relationships_as_dependent
                                .joins(:guardian_user)
                                .first&.guardian_user
  end



  private

  def reset_all_caches
    @available_capabilities = nil
    @inherent_capabilities = nil
    @loaded_capabilities = nil
  end

  def active_application
    applications.where.not(status: 'draft').order(created_at: :desc).first
  end

  def format_phone_number
    return if phone.blank?

    # Strip all non-digit characters
    digits = phone.gsub(/\D/, '')

    # Remove leading '1' if present
    digits = digits[1..] if digits.length == 11 && digits.start_with?('1')

    # Format as XXX-XXX-XXXX if we have 10 digits or keep original
    self.phone = if digits.length == 10
                   digits.gsub(/(\d{3})(\d{3})(\d{4})/, '\1-\2-\3')
                 else
                   # Keep the original input if invalid
                   phone
                 end
  end

  def phone_number_must_be_valid
    return if phone.blank?

    # Strip all non-digit characters
    digits = phone.gsub(/\D/, '')

    # Remove leading '1' if present
    digits = digits[1..] if digits.length == 11 && digits.start_with?('1')

    # Validate that there are exactly 10 digits
    errors.add(:phone, 'must be a valid 10-digit US phone number') if digits.length != 10
  end

  def dependent_phone_number_must_be_valid
    return if dependent_phone.blank?

    # Strip all non-digit characters
    digits = dependent_phone.gsub(/\D/, '')

    # Remove leading '1' if present
    digits = digits[1..] if digits.length == 11 && digits.start_with?('1')

    # Validate that there are exactly 10 digits
    errors.add(:dependent_phone, 'must be a valid 10-digit US phone number') if digits.length != 10
  end

  def available_capabilities_list
    base = RoleCapability::CAPABILITIES.dup
    base -= ['can_evaluate'] if evaluator? || admin?
    base -= ['can_train'] if trainer? || admin?
    base
  end

  def inherent_capabilities_list
    caps = []
    caps << 'can_evaluate' if evaluator? || admin?
    caps << 'can_train' if trainer? || admin?
    caps
  end

  def validate_address_for_letter_preference
    # Fix the comparison to use the enum correctly
    return unless communication_preference.to_s == 'letter' || communication_preference == :letter

    # Validate that address fields are present when letter preference is selected
    errors.add(:physical_address_1, 'is required when notification method is set to letter') if physical_address_1.blank?

    errors.add(:city, 'is required when notification method is set to letter') if city.blank?

    errors.add(:state, 'is required when notification method is set to letter') if state.blank?

    return if zip_code.present?

    errors.add(:zip_code, 'is required when notification method is set to letter')
  end

  # Custom validation for constituent disability
  def constituent_must_have_disability
    # Only apply to Users::Constituent type
    return unless type == 'Users::Constituent'

    # Add error if no disability is selected
    errors.add(:base, 'At least one disability must be selected.') unless disability_selected?
  end

  # Determine when to validate constituent disability
  # This should not run during initial account creation
  def validate_constituent_disability?
    return false unless type == 'Users::Constituent'
    return false if new_record? # Skip during initial creation

    # Only validate when updating existing users with applications
    # or when explicitly requested via an application submission
    applications.exists? || @validate_disability_required
  end

  # Check if any profile fields changed
  def saved_changes_to_profile_fields?
    profile_fields = %w[first_name last_name email phone physical_address_1 physical_address_2 city state zip_code date_of_birth]
    profile_fields.any? { |field| saved_change_to_attribute?(field) }
  end

  # Log profile changes to Event model
  def log_profile_changes
    changed_attributes = {}
    profile_fields = %w[first_name last_name email phone physical_address_1 physical_address_2 city state zip_code date_of_birth]

    profile_fields.each do |field|
      if saved_change_to_attribute?(field)
        old_value, new_value = saved_change_to_attribute(field)
        changed_attributes[field] = { old: old_value, new: new_value }
      end
    end

    return unless changed_attributes.present?

    # Determine who made the change
    actor = Current.user || self
    action = actor == self ? 'profile_updated' : 'profile_updated_by_guardian'

    Event.create!(
      user: actor,
      action: action,
      metadata: {
        user_id: id,
        changes: changed_attributes,
        updated_by: actor.id,
        timestamp: Time.current.iso8601
      }
    )
  end

  def email_must_be_unique
    return if email.blank?

    # WORKAROUND: Use the helper method that works with encrypted columns
    existing = User.exists_with_email?(email, excluding_id: id)
    errors.add(:email, 'has already been taken') if existing
  rescue StandardError => e
    Rails.logger.warn "Email uniqueness check failed: #{e.message}"
    # Don't add validation error on database errors - let the unique index catch it
  end

  def phone_must_be_unique
    return if phone.blank?

    # WORKAROUND: Use the helper method that works with encrypted columns
    existing = User.exists_with_phone?(phone, excluding_id: id)
    errors.add(:phone, 'has already been taken') if existing
  rescue StandardError => e
    Rails.logger.warn "Phone uniqueness check failed: #{e.message}"
    # Don't add validation error on database errors - let the unique index catch it
  end
end
