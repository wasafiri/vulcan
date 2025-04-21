# frozen_string_literal: true

# User model that serves as the base class for all user types in the system
class User < ApplicationRecord
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

  has_secure_password

  # Constants
  MAX_LOGIN_ATTEMPTS = 5
  PASSWORD_RESET_EXPIRY = 20.minutes
  LOCK_DURATION = 1.hour
  VALID_ROLES = %w[admin constituent evaluator vendor trainer].freeze

  # Format phone numbers to include dashes
  before_save :format_phone_number

  # Callbacks
  after_save :reset_all_caches

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
  # removed: has_many :activities, dependent: :destroy

  has_and_belongs_to_many :products,
                          join_table: 'products_users'

  # Two-Factor Authentication Associations
  has_many :webauthn_credentials, dependent: :destroy
  has_many :totp_credentials, dependent: :destroy
  has_many :sms_credentials, dependent: :destroy

  # Validations
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :email, presence: true,
                    uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true
  validates :reset_password_token, uniqueness: true, allow_nil: true
  validate :phone_number_must_be_valid
  validate :validate_address_for_letter_preference
  # validate :constituent_must_have_disability # Added validation

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
  scope :with_capability, lambda { |capability|
    joins(:role_capabilities)
      .where(role_capabilities: { capability: capability })
      .or(where(type: capable_types_for(capability)))
  }
  scope :admins, -> { where(type: 'Users::Administrator') }
  scope :vendors, -> { where(type: 'Vendor') }
  scope :ordered_by_name, -> { order(:first_name) }
  scope :locked, -> { where.not(locked_at: nil) }

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

  def self.digest(string)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
    BCrypt::Password.create(string, cost: cost)
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

  def track_failed_attempt!
    increment!(:failed_attempts)
    lock_account! if failed_attempts >= MAX_LOGIN_ATTEMPTS
  end

  def lock_account!
    update!(locked_at: Time.current)
  end

  def locked?
    locked_at? && locked_at > LOCK_DURATION.ago
  end

  # Password reset methods
  def generate_password_reset_token!
    update(
      reset_password_token: SecureRandom.urlsafe_base64,
      reset_password_sent_at: Time.current
    )
  end

  def clear_reset_password_token!
    update(
      reset_password_token: nil,
      reset_password_sent_at: nil
    )
  end

  def password_reset_expired?
    reset_password_sent_at.nil? || reset_password_sent_at < PASSWORD_RESET_EXPIRY.ago
  end

  def preloaded_capabilities
    role_capabilities.loaded? ? role_capabilities : []
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

  def cached_capabilities
    @cached_capabilities ||= {
      available: available_capabilities_list,
      inherent: inherent_capabilities_list,
      preloaded: role_capabilities.to_a
    }
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

  private

  def reset_all_caches
    @cached_capabilities = nil
    @preloaded_capabilities = nil
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
    errors.add(:physical_address1, 'is required when notification method is set to letter') if physical_address_1.blank?

    errors.add(:city, 'is required when notification method is set to letter') if city.blank?

    errors.add(:state, 'is required when notification method is set to letter') if state.blank?

    return if zip_code.present?

    errors.add(:zip_code, 'is required when notification method is set to letter')
  end

  # Custom validation for constituent disability
  def constituent_must_have_disability
    # Only apply to existing Users::Constituent type (skip during initial registration)
    # because we want them to select a disability on constituent_portal/applications#new instead
    return unless type == 'Users::Constituent' && !new_record?

    errors.add(:base, 'At least one disability must be selected.') unless disability_selected?
  end
end
