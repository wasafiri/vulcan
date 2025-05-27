# frozen_string_literal: true

require 'bcrypt'

# User model that serves as the base class for all user types in the system
class User < ApplicationRecord
  # Token generation for email verification and password reset
  generates_token_for :password_reset, expires_in: 20.minutes
  generates_token_for :email_verification, expires_in: 1.day

  # Ensure duplicate review flag is accessible
  attr_accessor :needs_duplicate_review unless column_names.include?('needs_duplicate_review')

  # DEPRECATED: These attributes will be removed in a future version.
  # Use GuardianRelationship model instead.
  # - is_guardian (boolean)
  # - guardian_relationship (string)
  # - guardian_id (bigint)

  # Class methods
  def self.system_user
    @system_user ||= begin
      user = User.find_or_create_by!(email: 'system@example.com') do |u|
        u.first_name = 'System'
        u.last_name = 'User'
        u.password = SecureRandom.hex(32)
        u.type = 'Users::Administrator'
        u.verified = true
      end
      user.admin? ? user : user.tap { |u| u.update!(type: 'Users::Administrator') }
    end
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
  after_save :reset_all_caches
  after_update :log_profile_changes, if: :saved_changes_to_profile_fields?

  # Associations
  has_many :sessions, dependent: :destroy
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

  # Validations
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  # Accessor for skipping contact uniqueness validation (used for dependent sharing guardian email/phone)
  attr_accessor :skip_contact_uniqueness_validation

  validates :email, presence: true,
                    uniqueness: { unless: :skip_contact_uniqueness_for_dependent? },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  # Add uniqueness validation for phone only when phone is present and non-blank
  # and not a dependent using guardian's contact
  validates :phone, uniqueness: { case_sensitive: false, allow_blank: true,
                                  unless: :skip_contact_uniqueness_for_dependent? }
  validates :first_name, :last_name, presence: true
  validates :reset_password_token, uniqueness: true, allow_nil: true
  validate :phone_number_must_be_valid # This still checks the 10-digit format
  validate :validate_address_for_letter_preference
  validate :constituent_must_have_disability, if: :validate_constituent_disability? # Only validate when appropriate

  # Status enum
  enum :status, { inactive: 0, active: 1, suspended: 2 }, default: :active

  # Communication preference enum
  enum :communication_preference, { email: 0, letter: 1 }, default: :email

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

  # Method to check if this user is dependent sharing guardian's contact info
  def skip_contact_uniqueness_for_dependent?
    # Handle both boolean and string values (form params may come as strings)
    [true, 'true', '1'].include?(skip_contact_uniqueness_validation)
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
end
