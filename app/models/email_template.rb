class EmailTemplate < ApplicationRecord
  belongs_to :updated_by, class_name: 'User', optional: true

  validates :name, presence: true, uniqueness: true
  validates :subject, :body, presence: true
  validate :validate_variables_in_body

  AVAILABLE_TEMPLATES = {
    'proof_rejection' => {
      required_vars: %w[constituent_name proof_type rejection_reason],
      optional_vars: %w[admin_name application_id]
    },
    'proof_approval' => {
      required_vars: %w[constituent_name proof_type],
      optional_vars: %w[admin_name application_id]
    },
    'medical_provider_request' => {
      required_vars: %w[provider_name constituent_name],
      optional_vars: %w[application_id]
    }
  }.freeze

  def self.render(template_name, **vars)
    template = find_by!(name: template_name)
    template.render(**vars)
  end

  def render(**vars)
    validate_required_variables!(vars)
    body_with_vars = body.dup

    vars.each do |key, value|
      body_with_vars.gsub!("%{#{key}}", value.to_s)
    end

    [subject, body_with_vars]
  end

  def render_with_tracking(variables, current_user)
    validate_required_variables!(variables)
    rendered_subject, rendered_body = render(variables)

    Event.create!(
      user: current_user,
      action: 'email_template_rendered',
      user_agent: Current.user_agent,
      ip_address: Current.ip_address
    )

    [rendered_subject, rendered_body]
  rescue StandardError
    Event.create!(
      user: current_user,
      action: 'email_template_error',
      user_agent: Current.user_agent,
      ip_address: Current.ip_address
    )
    raise
  end

  private

  def validate_variables_in_body
    required_vars = AVAILABLE_TEMPLATES[name]&.dig(:required_vars) || []

    required_vars.each do |var|
      errors.add(:body, "must include the variable %{#{var}}") unless body.include?("%{#{var}}")
    end
  end

  def validate_required_variables!(vars)
    required_vars = AVAILABLE_TEMPLATES[name]&.dig(:required_vars) || []
    missing_vars = required_vars - vars.keys.map(&:to_s)

    return unless missing_vars.any?

    raise ArgumentError, "Missing required variables: #{missing_vars.join(', ')}"
  end
end
