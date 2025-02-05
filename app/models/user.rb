class User < ApplicationRecord
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
    class_name: "Notification",
    foreign_key: :recipient_id,
    dependent: :destroy
  has_many :applications, foreign_key: :user_id
  has_many :role_capabilities, dependent: :destroy
  has_many :devices, dependent: :destroy
  has_many :activities, dependent: :destroy

  has_and_belongs_to_many :products,
    join_table: "products_users"

  # Validations
  validates :password, length: { minimum: 8 }, if: -> { password.present? }
  validates :email, presence: true,
    uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true
  validates :reset_password_token, uniqueness: true, allow_nil: true
  validates :phone, format: {
  with: /\A\d{3}-\d{3}-\d{4}\z/,
  message: "must be in format XXX-XXX-XXXX"
  }

  # Scopes
  scope :with_capability, ->(capability) {
    joins(:role_capabilities)
      .where(role_capabilities: { capability: capability })
      .or(where(type: capable_types_for(capability)))
  }
  scope :vendors, -> { where(type: "Vendor") }
  scope :ordered_by_name, -> { order(:first_name) }
  scope :locked, -> { where.not(locked_at: nil) }

  # Basic user information
  def full_name
    [ first_name, last_name ].compact.join(" ")
  end

  # Role methods
  VALID_ROLES.each do |role|
    define_method "#{role}?" do
      type == role.classify
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
    RoleCapability::CAPABILITIES - inherent_capabilities
  end

  def has_capability?(capability)
    inherent_capabilities.include?(capability) ||
      role_capabilities.exists?(capability: capability)
  end

  def prevent_self_role_update(current_user, new_role)
    !(self == current_user && type != new_role)
  end

  def add_capability(capability)
    return true if has_capability?(capability)
    role_capabilities.create(capability: capability)
  end

  def remove_capability(capability)
    return true if !has_capability?(capability)
    role_capabilities.find_by(capability: capability)&.destroy
  end

  def is_guardian=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def hearing_disability=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def vision_disability=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def speech_disability=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def mobility_disability=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def cognition_disability=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  private

  def reset_all_caches
    @cached_capabilities = nil
    @preloaded_capabilities = nil
    @available_capabilities = nil
    @inherent_capabilities = nil
    @loaded_capabilities = nil
  end

  def cached_capabilities
    @cached_capabilities ||= {
      available: begin
        base = RoleCapability::CAPABILITIES
        base -= [ "can_evaluate" ] if evaluator? || admin?
        base -= [ "can_train" ] if trainer? || admin?
        base
      end,
      inherent: begin
        caps = []
        caps << "can_evaluate" if evaluator? || admin?
        caps << "can_train" if trainer? || admin?
        caps
      end,
      preloaded: role_capabilities.to_a
    }
  end

  def active_application
    applications.where.not(status: "draft").order(created_at: :desc).first
  end

  def is_guardian=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def guardian_relationship=(value)
    super(value)
  end

  def format_phone_number
    return if phone.blank?

    # Strip all non-digits
    digits = phone.gsub(/\D/, "")

    # Remove leading 1 if present
    digits = digits[1..-1] if digits.length == 11 && digits.start_with?("1")

    # Format as XXX-XXX-XXXX if we have 10 digits
    if digits.length == 10
      self.phone = digits.gsub(/(\d{3})(\d{3})(\d{4})/, '\1-\2-\3')
    end
  end
end
