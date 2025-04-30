# frozen_string_literal: true

class EvaluatorMailer < ApplicationMailer
  include Rails.application.routes.url_helpers
  # Include helpers for rendering shared partials
  include Mailers::SharedPartialHelpers # Use the extracted shared helper module

  def self.default_url_options
    Rails.application.config.action_mailer.default_url_options
  end

  # Notify an evaluator that a new evaluation has been assigned
  # Expects evaluation passed via .with(evaluation: ...)
  def new_evaluation_assigned
    evaluation = params[:evaluation] # Use params
    template_name = 'evaluator_mailer_new_evaluation_assigned'
    begin
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email templates not found for #{template_name}"
    end

    # Prepare variables
    evaluator = evaluation.evaluator
    constituent = evaluation.constituent
    application = evaluation.application

    # Assuming a route helper exists for the evaluator's evaluation page
    evaluators_evaluation_url = begin
      evaluators_evaluation_url(evaluation, host: default_url_options[:host])
    rescue StandardError
      '#'
    end

    # Common elements for shared partials
    header_title = "New Evaluation Assigned - Application ##{application.id}"
    footer_contact_email = Policy.get('support_email') || 'support@example.com'
    footer_website_url = root_url(host: default_url_options[:host])
    footer_show_automated_message = true
    header_logo_url = begin
      ActionController::Base.helpers.asset_path('logo.png', host: default_url_options[:host])
    rescue StandardError
      nil
    end

    variables = {
      evaluator_full_name: evaluator.full_name,
      constituent_full_name: constituent.full_name,
      constituent_address_formatted: [
        constituent.physical_address_1, # Corrected attribute name
        constituent.physical_address_2, # Corrected attribute name
        "#{constituent.city}, #{constituent.state} #{constituent.zip_code}"
      ].compact_blank.join("\n"),
      constituent_phone_formatted: constituent.phone || 'Not Provided', # Use 'phone' attribute from factory
      constituent_email: constituent.email,
      evaluators_evaluation_url: evaluators_evaluation_url,
      # Optional variables
      constituent_disabilities_html_list: if constituent.disabilities.present?
                                            "<ul>#{constituent.disabilities.map do |d|
                                              "<li>#{d}</li>"
                                            end.join}</ul>"
                                          else
                                            ''
                                          end,
      constituent_disabilities_text_list: constituent.disabilities.present? ? constituent.disabilities.map { |d| "- #{d}" }.join("\n") : '',
      # Shared partial variables (rendered content)
      header_text: header_text(title: header_title, logo_url: header_logo_url),
      footer_text: footer_text(contact_email: footer_contact_email, website_url: footer_website_url,
                               show_automated_message: footer_show_automated_message),
      header_logo_url: header_logo_url, # Optional, passed for potential use in template body
      header_subtitle: nil # Optional
    }.compact

    # Render subject and body from text template
    rendered_subject, rendered_text_body = text_template.render(**variables)

    # Send email
    mail(
      to: evaluator.email,
      subject: rendered_subject,
      message_stream: 'notifications'
    ) do |format|
      format.text { render plain: rendered_text_body.to_s }
    end
  rescue StandardError => e
    # Log error with more details
    Event.create!(
      user: evaluator, # Use local variable
      action: 'email_delivery_error',
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: template_name, # Use local variable
        variables: variables.except(:header_html, :header_text, :footer_html, :footer_text, :constituent_disabilities_html_list, :constituent_disabilities_text_list), # Avoid logging large HTML/text blocks
        backtrace: e.backtrace&.first(5)
      }
    )
    raise
  end

  # Notify a constituent that their evaluation has been submitted
  # Expects evaluation passed via .with(evaluation: ...)
  def evaluation_submission_confirmation
    evaluation = params[:evaluation] # Use params
    template_name = 'evaluator_mailer_evaluation_submission_confirmation'
    begin
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email templates not found for #{template_name}"
    end

    # Prepare variables
    constituent = evaluation.constituent
    application = evaluation.application
    evaluator = evaluation.evaluator
    submission_date_formatted = evaluation.submitted_at&.strftime('%B %d, %Y at %I:%M %p %Z') || 'Not Provided'

    # Common elements for shared partials
    header_title = "Your Evaluation has been Submitted - Application ##{application.id}"
    footer_contact_email = Policy.get('support_email') || 'support@example.com'
    footer_website_url = root_url(host: default_url_options[:host])
    footer_show_automated_message = true
    header_logo_url = begin
      ActionController::Base.helpers.asset_path('logo.png', host: default_url_options[:host])
    rescue StandardError
      nil
    end

    variables = {
      constituent_first_name: constituent.first_name,
      application_id: application.id,
      evaluator_full_name: evaluator.full_name,
      submission_date_formatted: submission_date_formatted,
      # Shared partial variables (rendered content)
      header_text: header_text(title: header_title, logo_url: header_logo_url),
      footer_text: footer_text(contact_email: footer_contact_email, website_url: footer_website_url,
                               show_automated_message: footer_show_automated_message),
      header_logo_url: header_logo_url, # Optional, passed for potential use in template body
      header_subtitle: nil # Optional
    }.compact

    # Render subject and body from text template
    rendered_subject, rendered_text_body = text_template.render(**variables)

    # Create a letter if the constituent prefers print communications
    if constituent.communication_preference == 'letter'
      Letters::TextTemplateToPdfService.new(
        template_name: 'evaluator_mailer_evaluation_submission_confirmation',
        recipient: constituent,
        variables: {
          constituent_first_name: constituent.first_name,
          application_id: application.id,
          evaluator_full_name: evaluator.full_name,
          submission_date_formatted: submission_date_formatted
        }
      ).queue_for_printing
    end

    # Send email (text only)
    mail(
      to: constituent.email,
      subject: rendered_subject,
      message_stream: 'notifications'
    ) do |format|
      format.text { render plain: rendered_text_body.to_s }
    end
  rescue StandardError => e
    Rails.logger.error("Failed to send evaluation submission confirmation email for evaluation #{evaluation&.id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  # Private helper methods were removed as they are now included via Mailers::SharedPartialHelpers
end
