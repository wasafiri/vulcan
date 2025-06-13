# frozen_string_literal: true

class VendorNotificationsMailer < ApplicationMailer
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::NumberHelper # For number_to_currency
  # Include helpers for rendering shared partials (e.g., status boxes for W9)
  include Mailers::SharedPartialHelpers # Use the extracted shared helper module

  def self.default_url_options
    Rails.application.config.action_mailer.default_url_options
  end

  # --- Refactored Methods ---

  def invoice_generated
    invoice = params[:invoice]
    vendor = invoice.vendor
    transactions = invoice.voucher_transactions.includes(:voucher)
    template_name = 'vendor_notifications_invoice_generated'

    begin
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email templates not found for #{template_name}"
    end

    # Prepare variables
    # Render transactions table to strings (simplified example)
    transactions_html_table = '<table><thead><tr><th>Date</th><th>Voucher</th><th>Amount</th></tr></thead><tbody>' +
                              transactions.map do |t|
                                "<tr><td>#{t.processed_at.strftime('%Y-%m-%d')}</td><td>#{t.voucher.code}</td><td>#{number_to_currency(t.amount)}</td></tr>"
                              end.join + '</tbody></table>'
    transactions_text_list = transactions.map do |t|
      "#{t.processed_at.strftime('%Y-%m-%d')} | #{t.voucher.code} | #{number_to_currency(t.amount)}"
    end.join("\n")

    variables = {
      vendor_business_name: vendor.business_name,
      invoice_number: invoice.invoice_number,
      period_start_formatted: invoice.period_start.strftime('%B %d, %Y'),
      period_end_formatted: invoice.period_end.strftime('%B %d, %Y'),
      total_amount_formatted: number_to_currency(invoice.total_amount),
      transactions_html_table: transactions_html_table,
      transactions_text_list: transactions_text_list
    }.compact

    # Render subject and body from text template
    rendered_subject, rendered_text_body = text_template.render(**variables)

    # Generate and attach PDF
    attachments["invoice-#{invoice.invoice_number}.pdf"] = generate_invoice_pdf(invoice, vendor, transactions)

    # Send email
    mail(
      to: vendor.email,
      subject: rendered_subject,
      message_stream: 'outbound' # Keep existing stream
    ) do |format|
      format.text { render plain: rendered_text_body }
    end
  rescue StandardError => e
    # Log error with more details
    Event.create!(
      user: vendor, # Assuming vendor is the relevant user context here
      action: 'email_delivery_error',
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: template_name,
        variables: variables.except(:transactions_html_table, :transactions_text_list), # Avoid logging large tables
        backtrace: e.backtrace&.first(5)
      }
    )
    raise e
  end

  def payment_issued
    invoice = params[:invoice]
    vendor = invoice.vendor
    template_name = 'vendor_notifications_payment_issued'

    begin
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email templates not found for #{template_name}"
    end

    # Prepare variables
    variables = {
      vendor_business_name: vendor.business_name,
      invoice_number: invoice.invoice_number,
      total_amount_formatted: number_to_currency(invoice.total_amount),
      gad_invoice_reference: invoice.gad_invoice_reference || 'N/A',
      check_number: invoice.check_number # Optional
    }.compact

    # Render subject and body from text template
    rendered_subject, rendered_text_body = text_template.render(**variables)

    # Send email
    mail(
      to: vendor.email,
      subject: rendered_subject,
      message_stream: 'outbound' # Keep existing stream
    ) do |format|
      format.text { render plain: rendered_text_body }
    end
  rescue StandardError => e
    # Log error with more details
    Event.create!(
      user: vendor,
      action: 'email_delivery_error',
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: template_name,
        variables: variables,
        backtrace: e.backtrace&.first(5)
      }
    )
    raise e
  end

  def w9_approved
    vendor = params[:vendor]
    template_name = 'vendor_notifications_w9_approved'
    variables = {} # Initialize variables

    begin
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email templates not found for #{template_name}"
    end

    # Prepare variables
    # Common elements for shared partials
    header_title = 'W9 Form Approved'
    footer_contact_email = Policy.get('support_email') || 'support@example.com'
    footer_organization_name = Policy.get('organization_name') || 'MAT Program'
    footer_website_url = root_url(host: default_url_options[:host])
    footer_show_automated_message = true
    header_logo_url = begin
      ActionController::Base.helpers.asset_path('logo.png', host: default_url_options[:host])
    rescue StandardError
      nil
    end
    status_box_title = 'W9 Approved'
    status_box_message = 'Your W9 form has been approved. No further action is needed at this time.'

    variables = {
      vendor_business_name: vendor.business_name,
      header_title: header_title,
      # Shared partials
      status_box_text: status_box_text(status: :success, title: status_box_title, message: status_box_message),
      header_text: header_text(title: header_title, logo_url: header_logo_url),
      footer_text: footer_text(organization_name: footer_organization_name, contact_email: footer_contact_email, website_url: footer_website_url,
                               show_automated_message: footer_show_automated_message),
      header_logo_url: header_logo_url, # Optional
      header_subtitle: nil # Optional
    }.compact

    # Render subject and body from text template
    rendered_subject, rendered_text_body = text_template.render(**variables)

    # Send email
    mail(
      to: vendor.email,
      subject: rendered_subject,
      message_stream: 'outbound' # Keep existing stream
    ) do |format|
      format.text { render plain: rendered_text_body }
    end
  rescue StandardError => e
    # Log error with more details
    Event.create!(
      user: vendor,
      action: 'email_delivery_error',
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: template_name,
        variables: variables.except(:status_box_html, :header_html, :footer_html), # Avoid logging large HTML blocks
        backtrace: e.backtrace&.first(5)
      }
    )
    raise e
  end

  def w9_rejected
    vendor = params[:vendor]
    w9_review = params[:w9_review] # Assuming review object is passed
    template_name = 'vendor_notifications_w9_rejected'
    variables = {} # Initialize variables

    begin
      # Only find the text template as per project strategy
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email template (text format) not found for #{template_name}"
    end

    # Prepare variables
    rejection_reason = w9_review&.rejection_reason || 'No reason provided.'
    # Use root_url instead of vendor_portal_root_url if the helper isn't defined
    vendor_portal_url = if defined?(vendor_portal_root_url)
                          vendor_portal_root_url(host: default_url_options[:host])
                        else
                          root_url(host: default_url_options[:host])
                        end

    # Common elements for shared partials
    header_title = 'W9 Form Requires Attention'
    footer_contact_email = Policy.get('support_email') || 'support@example.com'
    footer_organization_name = Policy.get('organization_name') || 'MAT Program'
    footer_website_url = root_url(host: default_url_options[:host])
    footer_show_automated_message = true
    header_logo_url = begin
      ActionController::Base.helpers.asset_path('logo.png', host: default_url_options[:host])
    rescue StandardError
      nil
    end
    status_box_title = 'W9 Rejected'
    status_box_message = "Your W9 form requires attention. Reason: #{rejection_reason}. Please visit the vendor portal to upload a corrected form."

    variables = {
      vendor_business_name: vendor.business_name,
      rejection_reason: rejection_reason,
      vendor_portal_url: vendor_portal_url,
      header_title: header_title,
      # Shared partials (text only for non-multipart emails)
      status_box_text: status_box_text(status: :error, title: status_box_title, message: status_box_message),
      header_text: header_text(title: header_title, logo_url: header_logo_url),
      footer_text: footer_text(organization_name: footer_organization_name, contact_email: footer_contact_email, website_url: footer_website_url,
                               show_automated_message: footer_show_automated_message),
      header_logo_url: header_logo_url, # Optional
      header_subtitle: nil # Optional
    }.compact

    # Render subject and body from the text template
    rendered_subject, rendered_text_body = text_template.render(**variables)

    # Send email as non-multipart text-only
    text_body = rendered_text_body.to_s
    Rails.logger.debug { "DEBUG: Preparing to send w9_rejected email with content: #{text_body.inspect}" }

    mail(
      to: vendor.email,
      subject: rendered_subject,
      message_stream: 'outbound', # Keep existing stream
      body: text_body,
      content_type: 'text/plain'
    )
  rescue StandardError => e
    # Log error with more details
    Event.create!(
      user: vendor,
      action: 'email_delivery_error',
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: template_name,
        variables: variables.except(:status_box_html, :header_html, :footer_html), # Avoid logging large HTML blocks
        backtrace: e.backtrace&.first(5)
      }
    )
    raise e
  end

  def w9_expiring_soon
    vendor = params[:vendor]
    template_name = 'vendor_notifications_w9_expiring_soon'

    begin
      # Only find the text template as per project strategy
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email template (text format) not found for #{template_name}"
    end

    # Prepare variables
    days_until_expiry = (vendor.w9_expiration_date - Date.current).to_i
    expiration_date_formatted = vendor.w9_expiration_date.strftime('%B %d, %Y')
    vendor_portal_url = if defined?(vendor_portal_root_url)
                          vendor_portal_root_url(host: default_url_options[:host])
                        else
                          root_url(host: default_url_options[:host])
                        end
    vendor_association_message = vendor.associated? ? 'Your association requires a valid W9.' : '' # Example optional message

    # Common elements for shared partials
    header_title = 'W9 Form Expiring Soon'
    footer_contact_email = Policy.get('support_email') || 'support@example.com'
    footer_organization_name = Policy.get('organization_name') || 'MAT Program'
    footer_website_url = root_url(host: default_url_options[:host])
    footer_show_automated_message = true
    header_logo_url = begin
      ActionController::Base.helpers.asset_path('logo.png', host: default_url_options[:host])
    rescue StandardError
      nil
    end
    status_box_warning_title = 'W9 Expiring Soon'
    status_box_warning_message = "Your W9 form on file will expire in #{days_until_expiry} days on #{expiration_date_formatted}."
    status_box_info_title = 'Action Required'
    status_box_info_message = "Please visit the vendor portal to upload a new W9 form to avoid any disruption. #{vendor_association_message}"

    variables = {
      vendor_business_name: vendor.business_name,
      days_until_expiry: days_until_expiry,
      expiration_date_formatted: expiration_date_formatted,
      vendor_portal_url: vendor_portal_url,
      header_title: header_title,
      # Shared partials (text only for non-multipart emails)
      status_box_warning_text: status_box_text(status: :warning, title: status_box_warning_title, message: status_box_warning_message),
      status_box_info_text: status_box_text(status: :info, title: status_box_info_title, message: status_box_info_message),
      header_text: header_text(title: header_title, logo_url: header_logo_url),
      footer_text: footer_text(contact_email: footer_contact_email, website_url: footer_website_url,
                               show_automated_message: footer_show_automated_message),
      # Optional
      vendor_association_message: vendor_association_message,
      header_logo_url: header_logo_url,
      header_subtitle: nil
    }.compact

    # Render subject and body from the text template
    rendered_subject, rendered_text_body = text_template.render(**variables)

    # Send email as non-multipart text-only
    text_body = rendered_text_body.to_s
    Rails.logger.debug { "DEBUG: Preparing to send w9_expiring_soon email with content: #{text_body.inspect}" }

    mail(
      to: vendor.email,
      subject: rendered_subject,
      message_stream: 'outbound', # Keep existing stream
      body: text_body,
      content_type: 'text/plain'
    )
  rescue StandardError => e
    # Log error with more details
    Event.create!(
      user: vendor,
      action: 'email_delivery_error',
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: template_name,
        variables: variables.except(:status_box_warning_html, :status_box_info_html, :header_html, :footer_html), # Avoid logging large HTML blocks
        backtrace: e.backtrace&.first(5)
      }
    )
    raise e
  end

  def w9_expired
    vendor = params[:vendor]
    template_name = 'vendor_notifications_w9_expired'

    begin
      # Only find the text template as per project strategy
      text_template = EmailTemplate.find_by!(name: template_name, format: :text)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Missing EmailTemplate for #{template_name}: #{e.message}"
      raise "Email template (text format) not found for #{template_name}"
    end

    # Prepare variables
    expiration_date_formatted = vendor.w9_expiration_date.strftime('%B %d, %Y')
    vendor_portal_url = if defined?(vendor_portal_root_url)
                          vendor_portal_root_url(host: default_url_options[:host])
                        else
                          root_url(host: default_url_options[:host])
                        end
    vendor_association_message = vendor.associated? ? 'Your association requires a valid W9.' : '' # Example optional message

    # Common elements for shared partials
    header_title = 'W9 Form Has Expired - Action Required'
    footer_contact_email = Policy.get('support_email') || 'support@example.com'
    footer_organization_name = Policy.get('organization_name') || 'MAT Program'
    footer_website_url = root_url(host: default_url_options[:host])
    footer_show_automated_message = true
    header_logo_url = begin
      ActionController::Base.helpers.asset_path('logo.png', host: default_url_options[:host])
    rescue StandardError
      nil
    end
    status_box_warning_title = 'W9 Expired'
    status_box_warning_message = "Your W9 form on file expired on #{expiration_date_formatted}."
    status_box_info_title = 'Action Required'
    status_box_info_message = "Please visit the vendor portal immediately to upload a new W9 form to avoid payment delays. #{vendor_association_message}"

    variables = {
      vendor_business_name: vendor.business_name,
      expiration_date_formatted: expiration_date_formatted,
      vendor_portal_url: vendor_portal_url,
      header_title: header_title,
      # Shared partials (text only for non-multipart emails)
      status_box_warning_text: status_box_text(status: :warning, title: status_box_warning_title, message: status_box_warning_message),
      status_box_info_text: status_box_text(status: :info, title: status_box_info_title, message: status_box_info_message),
      header_text: header_text(title: header_title, logo_url: header_logo_url),
      footer_text: footer_text(contact_email: footer_contact_email, website_url: footer_website_url,
                               show_automated_message: footer_show_automated_message),
      # Optional
      vendor_association_message: vendor_association_message,
      header_logo_url: header_logo_url,
      header_subtitle: nil
    }.compact

    # Render subject and body from the text template
    rendered_subject, rendered_text_body = text_template.render(**variables)

    # Send email as non-multipart text-only
    text_body = rendered_text_body.to_s
    Rails.logger.debug { "DEBUG: Preparing to send w9_expired email with content: #{text_body.inspect}" }

    mail(
      to: vendor.email,
      subject: rendered_subject,
      message_stream: 'outbound', # Keep existing stream
      body: text_body,
      content_type: 'text/plain'
    )
  rescue StandardError => e
    # Log error with more details
    Event.create!(
      user: vendor,
      action: 'email_delivery_error',
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: template_name,
        variables: variables.except(:status_box_warning_html, :status_box_info_html, :header_html, :footer_html), # Avoid logging large HTML blocks
        backtrace: e.backtrace&.first(5)
      }
    )
    raise e
  end

  private

  # Updated to accept arguments instead of relying on instance variables
  def generate_invoice_pdf(invoice, vendor, transactions)
    pdf = Prawn::Document.new do |pdf|
      # Header
      pdf.text 'INVOICE', size: 24, style: :bold, align: :center
      pdf.move_down 20

      # Invoice Details
      pdf.text "Invoice Number: #{invoice.invoice_number}"
      pdf.text "Date: #{invoice.created_at.strftime('%B %d, %Y')}"
      pdf.move_down 20

      # Vendor Information
      pdf.text 'Vendor:', style: :bold
      pdf.text vendor.business_name
      pdf.text vendor.business_tax_id
      pdf.move_down 20

      # Period
      pdf.text 'Period:', style: :bold
      pdf.text "#{invoice.period_start.strftime('%B %d, %Y')} - #{invoice.period_end.strftime('%B %d, %Y')}"
      pdf.move_down 20

      # Transactions Table
      items = [%w[Date Voucher Amount]]
      transactions.each do |transaction|
        items << [
          transaction.processed_at.strftime('%Y-%m-%d'),
          transaction.voucher.code,
          number_to_currency(transaction.amount) # Use helper directly
        ]
      end

      pdf.table(items, header: true) do |table|
        table.row(0).style(background_color: 'CCCCCC')
        table.cells.padding = 12
        table.column_widths = [150, 200, 150]
      end

      pdf.move_down 20

      # Total
      pdf.text "Total Amount: #{number_to_currency(invoice.total_amount)}", # Use helper directly
               size: 14,
               style: :bold,
               align: :right

      # Footer
      pdf.move_down 40
      pdf.text 'Please allow up to 30 days for payment processing.', size: 10
      pdf.text "Contact #{Policy.get('support_email') || 'support@example.com'} for any questions.", size: 10 # Use Policy
    end

    pdf.render
  end
end
