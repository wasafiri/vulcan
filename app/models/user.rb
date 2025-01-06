class User < ApplicationRecord
  has_secure_password

  # Associations
  has_many :sessions, dependent: :destroy
  has_many :received_notifications,
           class_name: "Notification",
           foreign_key: :recipient_id,
           dependent: :destroy
  has_many :applications, foreign_key: :user_id
  has_many :role_capabilities, dependent: :destroy

  # Validations
  validates :email, presence: true,
                   uniqueness: true,
                   format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, presence: true

  # Scopes
  scope :with_capability, ->(capability) {
    joins(:role_capabilities)
      .where(role_capabilities: { capability: capability })
      .or(where(type: capable_types_for(capability)))
  }

  # Basic user information
  def full_name
    [ first_name, last_name ].compact.join(" ")
  end

  # Class methods
  class << self
    def authenticate_by(email:, password:)
      user = find_by(email: email)
      user&.authenticate(password)
    end

    def capable_types_for(capability)
      case capability
      when "can_evaluate"
        [ "Admin", "Evaluator" ]
      when "can_train"
        [ "Admin", "Trainer" ]
      else
        [ "Admin" ]
      end
    end
  end

  # Authentication methods
  def track_sign_in!(ip)
    update(
      last_sign_in_at: Time.current,
      last_sign_in_ip: ip,
      failed_attempts: 0
    )
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

  # Role methods
  def role_type
    self.type
  end

  def prevent_self_role_update(current_user, new_role)
    return true unless self == current_user

    errors.add(:base, "You cannot change your own role.")
    false
  end

  # Role check methods using STI
  %w[admin constituent evaluator vendor trainer medical_provider].each do |role|
    define_method "#{role}?" do
      is_a?(role.classify.constantize)
    end
  end

  # Capability methods
  def available_capabilities
    @available_capabilities ||= begin
      base_capabilities = RoleCapability::CAPABILITIES
      base_capabilities -= [ "can_evaluate" ] if evaluator? || admin?
      base_capabilities -= [ "can_train" ] if trainer? || admin?
      base_capabilities
    end
  end

  def inherent_capabilities
    @inherent_capabilities ||= begin
      capabilities = []
      capabilities << "can_evaluate" if evaluator? || admin?
      capabilities << "can_train" if trainer? || admin?
      capabilities
    end
  end

  def preloaded_capabilities
    @preloaded_capabilities ||= role_capabilities.to_a
  end

  def has_capability?(capability)
    # Returns true if user’s primary role inherently provides the capability,
    # or if the user has an associated RoleCapability record for it.
    return true if inherent_capabilities.include?(capability)
    return preloaded_capabilities.any? { |rc| rc.capability == capability } if association(:role_capabilities).loaded?
    return @loaded_capabilities.include?(capability) if defined?(@loaded_capabilities)

    role_capabilities.exists?(capability: capability)
  end

  def add_capability(capability)
    # If the capability is already inherent to the user’s role, add an error
    # describing why it can’t be assigned again.
    if inherent_capabilities.include?(capability)
      errors.add(:base, "The user already has the “#{capability.titleize}” capability inherently from their primary role and it cannot be manually added.")
      return false
    end

    # If the user already has it assigned, add an error describing that duplication.
    if has_capability?(capability)
      errors.add(:base, "The user already has the “#{capability.titleize}” capability; no need to add again.")
      return false
    end

    # Otherwise attempt to create it
    role_capability = role_capabilities.create(capability: capability)
    @preloaded_capabilities = nil # Reset cache
    role_capability
  end

  def remove_capability(capability)
    return false if inherent_capabilities.include?(capability)
    # Attempt to find the matching RoleCapability record
    rc = role_capabilities.find_by(capability: capability)
    if rc
      rc.destroy
      @preloaded_capabilities = nil # Reset the local cache
      rc
    else
      # Add a custom error message indicating the user doesn't have this capability
      errors.add(:base, "The user doesn’t currently have the “#{capability.titleize}” capability assigned.")
      false
    end
  end

  def can_evaluate?
    evaluator? || admin? || has_capability?("can_evaluate")
  end

  def can_train?
    trainer? || admin? || has_capability?("can_train")
  end

  def load_capabilities
    @loaded_capabilities = role_capabilities.pluck(:capability)
  end

  private

  def reset_capability_cache
    @preloaded_capabilities = nil
    @available_capabilities = nil
    @inherent_capabilities = nil
    @loaded_capabilities = nil
  end
end
