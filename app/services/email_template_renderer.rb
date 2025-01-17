class EmailTemplateRenderer
  def self.render(template_name, vars = {})
    new(template_name, vars).render
  end

  def initialize(template_name, vars)
    @template_name = template_name
    @vars = vars
  end

  def render
    template = find_template
    validate_variables!(template)
    render_template(template)
  rescue ActiveRecord::RecordNotFound
    log_error("Template '#{@template_name}' not found")
    fallback_template
  rescue ArgumentError => e
    log_error("Variable validation failed: #{e.message}")
    fallback_template
  rescue => e
    log_error("Unexpected error rendering template: #{e.message}")
    fallback_template
  end

  private

  def find_template
    EmailTemplate.find_by!(name: @template_name)
  end

  def validate_variables!(template)
    required = template.required_variables
    missing = required - @vars.keys.map(&:to_s)
    raise ArgumentError, "Missing variables: #{missing.join(', ')}" if missing.any?
  end

  def render_template(template)
    body = template.body.dup
    @vars.each do |key, value|
      body.gsub!("%{#{key}}", value.to_s)
    end
    [ template.subject, body ]
  end

  def fallback_template
    [ "Application Update", generate_fallback_content ]
  end

  def generate_fallback_content
    case @template_name
    when "proof_rejection"
      "Your application requires attention. Please log in to your account for details."
    when "medical_provider_request"
      "A medical certification is needed for a patient's application."
    else
      "Please check your application status online."
    end
  end

  def log_error(message)
    Rails.logger.error("EmailTemplateRenderer Error: #{message}")
    Error.create!(
      message: message,
      context: {
        template_name: @template_name,
        variables: @vars
      }
    )
  end
end
