# frozen_string_literal: true

module Mailers
  # Shared helper methods for rendering common mailer partials like headers and footers.
  module SharedPartialHelpers
    extend ActiveSupport::Concern # Use Concern to manage dependencies and class methods if needed later

    included do
      # Ensure url_helpers are available if not already included in the mailer
      # include Rails.application.routes.url_helpers unless self.included_modules.include?(Rails.application.routes.url_helpers)

      # Helper method to access ActionView helpers like asset_path if needed within partials
      # helper :application # Or specific helpers
    end

    private

    # Renders a shared mailer partial to a string for inclusion in templates.
    # Caches rendered partials for efficiency within a single mailer invocation.
    # Assumes the mailer instance calling this has `render_to_string` available.
    def render_shared_partial_to_string(partial_name, format, locals = {})
      # Thread.current to store cache instead of instance variables
      Thread.current[:rendered_partials_cache] ||= {}
      # Use a more robust cache key that handles different object instances correctly
      cache_key = [partial_name, format, locals.to_s] # Convert locals to string for hashing consistency
      Thread.current[:rendered_partials_cache][cache_key] ||= render_to_string(
        partial: "shared/mailers/#{partial_name}",
        formats: [format], # Ensure correct format is rendered
        locals: locals
      ).freeze # Freeze the string to prevent accidental modification
    rescue ActionView::MissingTemplate => e
      Rails.logger.error "Missing shared mailer partial: shared/mailers/#{partial_name} for format #{format}. Error: #{e.message}"
      # Return a placeholder or raise a more specific error
      # Ensure render_to_string is available in the context including this module
      "Error: Missing partial 'shared/mailers/#{partial_name}' for format #{format}"
    rescue StandardError => e
      Rails.logger.error "Error rendering shared mailer partial: shared/mailers/#{partial_name}. Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      "Error rendering partial '#{partial_name}'"
    end

    # Renders an email template to a string for inclusion in other templates.
    # Caches rendered templates for efficiency within a single mailer invocation.
    def render_email_template(template_name, format, locals = {})
      Thread.current[:rendered_templates_cache] ||= {}
      cache_key = [template_name, format, locals.to_s] # Convert locals to string for hashing consistency

      Thread.current[:rendered_templates_cache][cache_key] ||= begin
        template = EmailTemplate.find_by(name: template_name, format: format)

        if template
          # Create a binding with locals for ERB evaluation
          template_str = template.body
          b = binding
          locals.each { |key, value| b.local_variable_set(key.to_sym, value) }

          # Render the template with the binding
          ERB.new(template_str).result(b).freeze
        else
          Rails.logger.error "Missing email template: #{template_name} for format #{format}"
          "Error: Missing email template '#{template_name}' for format #{format}"
        end
      rescue StandardError => e
        Rails.logger.error "Error rendering email template: #{template_name}. Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        "Error rendering email template '#{template_name}'"
      end
    end

    # --- Specific helpers for common templates ---

    # Renders the text header template.
    # Expects locals like: :title, :subtitle (optional)
    def header_text(locals = {})
      render_email_template('email_header_text', :text, locals)
    end

    # Renders the text footer template.
    # Expects locals like: :contact_email, :website_url, :organization_name, :show_automated_message (boolean)
    def footer_text(locals = {})
      render_email_template('email_footer_text', :text, locals)
    end

    # Generates a simple text representation for a status box.
    # Expects locals like: :status, :title, :message
    def status_box_text(status:, title:, message:)
      # Simple text representation, can be enhanced if needed
      "[#{status.to_s.upcase}] #{title}: #{message}"
    end
  end
end
