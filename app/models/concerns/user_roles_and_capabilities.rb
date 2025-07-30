# frozen_string_literal: true

# Concern for handling user roles and capabilities.
module UserRolesAndCapabilities
  extend ActiveSupport::Concern

  # Constants
  VALID_ROLES = %w[admin constituent evaluator vendor trainer].freeze

  included do
    # Associations
    has_many :role_capabilities, dependent: :destroy

    # Scopes
    scope :admins, -> { where(type: 'Users::Administrator') }
    scope :vendors, -> { where(type: 'Users::Vendor') }
  end

  # Class methods
  class_methods do
    def capable_types_for(capability)
      case capability
      when 'can_train'
        %w[Users::Administrator Users::Trainer]
      when 'can_evaluate'
        %w[Users::Administrator Users::Evaluator]
      else
        []
      end
    end
  end

  # Role methods
  def admin?
    is_a?(Users::Administrator)
  end

  VALID_ROLES.each do |role|
    next if role == 'admin' # admin? is handled separately

    define_method "#{role}?" do
      # Check for both namespaced and non-namespaced type values
      self.class.name == "Users::#{role.classify}" ||
        type == "Users::#{role.classify}" ||
        type == role.classify
    end
  end

  def role_type
    type.to_s.underscore.humanize
  end

  def inherent_capabilities
    role_capabilities.pluck(:capability)
  end

  def available_capabilities
    RoleCapability::CAPABILITIES
  end

  def capability?(capability)
    role_capabilities.exists?(capability: capability)
  end

  def prevent_self_role_update?(current_user, new_role)
    !(self == current_user && type != new_role)
  end

  def add_capability(capability)
    return true if capability?(capability)

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
    return true unless capability?(capability)

    role_capabilities.find_by(capability: capability)&.destroy
  end

  private

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
end
