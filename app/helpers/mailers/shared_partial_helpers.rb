# frozen_string_literal: true

module Mailers
  # Shared helper methods for rendering common mailer partials and templates.
  module SharedPartialHelpers
    extend ActiveSupport::Concern

    included do
      # Ensure path and url helpers are available
      include Rails.application.routes.url_helpers
      helper :application
    end

    private

    # Central cache for rendered content within a mailer invocation
    def mailer_cache
      Thread.current[:mailer_render_cache] ||= {}
    end

    # Generic helper for caching and rendering blocks
    def fetch_from_cache(key, &block)
      mailer_cache[key] ||= begin
        result = block.call.freeze
        result
      end
    rescue StandardError => e
      Rails.logger.error "Error during cached render (#{key.first}): #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      # Return a generic error message for safety
      "Error rendering #{key.first} '#{key[1]}'"
    end

    # Renders a shared mailer partial (ERB) to string, with caching.
    def render_shared_partial_to_string(partial_name, format, locals = {})
      key = [:partial, partial_name, format, locals.hash]
      fetch_from_cache(key) do
        render_to_string(
          partial: "shared/mailers/#{partial_name}",
          formats: [format],
          locals: locals
        )
      end
    rescue ActionView::MissingTemplate => e
      Rails.logger.error "Missing shared mailer partial: shared/mailers/#{partial_name} (#{e.message})"
      "Error: Missing partial 'shared/mailers/#{partial_name}' for format #{format}"
    end

    # Renders an email template stored in DB, using ActionView to avoid ERB injection,
    # with caching.
    def render_email_template(template_name, format, locals = {})
      key = [:template, template_name, format, locals.hash]
      fetch_from_cache(key) do
        template = EmailTemplate.find_by(name: template_name, format: format)
        unless template
          Rails.logger.error "Missing email template: #{template_name} for format #{format}"
          return "Error: Missing email template '#{template_name}' for format #{format}"
        end

        # Rails 8 requires proper ActionView::Base initialization with empty template cache
        view_context = ActionView::Base.with_empty_template_cache.new(
          ActionView::LookupContext.new([]),
          {},
          ActionController::Base.new
        )
        view_context.render(
          inline: template.body,
          type: :erb,
          locals: locals
        )
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
      "[#{status.to_s.upcase}] #{title}: #{message}"
    end
  end
end
