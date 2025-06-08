
# frozen_string_literal: true

# Service for notifying medical providers through different communication channels
class MedicalProviderNotifier
  class NotificationError < StandardError; end

  attr_reader :application, :proof_review

  def initialize(application, proof_review = nil)
    @application = application
    @proof_review = proof_review
    @fax_service = FaxService.new
  end

  # Notify the medical provider about a rejected certification
  # Uses fax if available, otherwise email
  # @param rejection_reason [String] The reason for rejection
  # @param admin [User] The admin who rejected the certification
  # @return [Boolean] Whether the notification was sent successfully
  def notify_certification_rejection(rejection_reason:, admin:)
    Rails.logger.info "Notifying medical provider about certification rejection for Application ID: #{application.id}"

    # Get the medical provider's contact info
    fax_number = application.medical_provider_fax
    email = application.medical_provider_email

    # Track delivery results
    delivery_result = { success: false }
    fax_sid = nil

    # Determine the communication method
    # Prefer fax if available, otherwise use email
    if fax_number.present?
      fax_result = notify_by_fax(rejection_reason)
      if fax_result[:success]
        delivery_result = { success: true, method: 'fax' }
        fax_sid = fax_result[:fax_sid]
      end
    end

    # If fax failed or not available, try email
    if !delivery_result[:success] && email.present?
      email_result = notify_by_email(rejection_reason, admin)
      if email_result[:success]
        delivery_result = { success: true, method: 'email', message_id: email_result[:message_id] }
      end
    end

    # Log the audit event first, regardless of delivery success
    AuditEventService.log(
      action: 'medical_certification_rejected',
      actor: admin,
      auditable: application,
      metadata: {
        rejection_reason: rejection_reason,
        medical_provider_name: application.medical_provider_name
      }
    )

    if delivery_result[:success]
      metadata = {
        medical_provider_name: application.medical_provider_name,
        rejection_reason: rejection_reason,
        notification_methods: notification_methods,
        delivery_method: delivery_result[:method]
      }
      
      # Add delivery-specific metadata
      if delivery_result[:method] == 'fax' && fax_sid.present?
        metadata[:fax_sid] = fax_sid
      elsif delivery_result[:method] == 'email' && delivery_result[:message_id].present?
        metadata[:message_id] = delivery_result[:message_id]
      end
      
      create_notification_record(admin, rejection_reason, metadata)
      return true
    else
      Rails.logger.error "Failed to notify medical provider for Application ID: #{application.id}. No valid contact methods available."
      return false
    end
  end

  private

  # Notify the medical provider using fax
  # @param rejection_reason [String] The reason for rejection
  # @return [Boolean] Whether the fax was sent successfully
  def notify_by_fax(rejection_reason)
    fax_number = application.medical_provider_fax
    # Generate a PDF for faxing
    pdf_path = generate_fax_pdf(rejection_reason)
    return { success: false, fax_sid: nil } unless pdf_path

    # Send the fax
    begin
      fax_result = @fax_service.send_pdf_fax(
        to: fax_number,
        pdf_path: pdf_path,
        options: {
          quality: 'fine',
          status_callback: Rails.application.routes.url_helpers.twilio_fax_status_url(
            host: Rails.application.config.action_mailer.default_url_options[:host]
          )
        }
      )

      if fax_result
        fax_sid = fax_result.sid
        Rails.logger.info "Fax successfully sent to medical provider for Application ID: #{application.id} - Fax SID: #{fax_sid}"
        return { success: true, fax_sid: fax_sid }
      end
    rescue FaxService::FaxError => e
      Rails.logger.error "Fax sending error for Application ID: #{application.id} - #{e.message}"
    rescue StandardError => e
      Rails.logger.error "Unexpected error sending fax for Application ID: #{application.id} - #{e.message}"
    ensure
      # Clean up the temporary PDF file if it exists
      FileUtils.rm_f(pdf_path) if pdf_path && File.exist?(pdf_path)
    end

    { success: false, fax_sid: nil }
  end

  # Notify the medical provider using email
  # @param rejection_reason [String] The reason for rejection
  # @param admin [User] The admin who rejected the certification
  # @return [Hash] Hash containing success status
  def notify_by_email(rejection_reason, admin)
    # Send the email - ensure message_id is captured for tracking
    mail = MedicalProviderMailer.certification_rejected(
      application,
      rejection_reason,
      admin
    )

    # Store message ID before delivering
    message_id = mail.message_id

    # Deliver later via background job
    mail.deliver_later

    Rails.logger.info "Email successfully queued for medical provider for Application ID: #{application.id} with message ID: #{message_id}"
    { success: true, message_id: message_id }
  rescue StandardError => e
    Rails.logger.error "Email sending error for Application ID: #{application.id} - #{e.message}"
    { success: false, message_id: nil }
  end

  # Generate a PDF document for faxing
  # @param rejection_reason [String] The reason for rejection
  # @return [String, nil] The path to the generated PDF, or nil if generation failed
  def generate_fax_pdf(rejection_reason)
    begin
      # Generate a temporary file path
      temp_file_path = Rails.root.join('tmp', "certification_rejection_#{application.id}_#{Time.now.to_i}.pdf")

      # Create the PDF using Prawn
      Prawn::Document.generate(temp_file_path) do |pdf|
        # Add logo
        # pdf.image Rails.root.join('app', 'assets', 'images', 'logo.png'), width: 200 if File.exist?(Rails.root.join('app', 'assets', 'images', 'logo.png'))

        # Add header
        pdf.text 'Maryland Accessible Telecommunications', size: 18, style: :bold
        pdf.move_down 10
        pdf.text 'Disability Certification Form for Patient needs Updates', size: 16, style: :bold
        pdf.move_down 20

        # Add patient information
        pdf.text "Patient: #{application.user.full_name}", size: 12
        pdf.text "Application ID: #{application.id}", size: 12
        pdf.move_down 20

        # Add rejection reason
        pdf.text 'Reason for Revision:', size: 14, style: :bold
        pdf.move_down 5
        pdf.text rejection_reason, size: 12
        pdf.move_down 20

        # Add remaining attempts information
        remaining_attempts = 8 - application.total_rejections
        pdf.text "Remaining Attempts: #{remaining_attempts}", size: 12
        pdf.move_down 20

        # Add instructions
        pdf.text "Instructions for Submitting Revised Documentation:", size: 14, style: :bold
        pdf.move_down 5
        pdf.text "1. Fax the revised certification to: 410-767-4276", size: 12
        pdf.text "2. Or reply to this communication with the revised certification attached", size: 12
        pdf.move_down 20

        # Add footer
        pdf.text "Thank you for your assistance in helping your patient access needed telecommunications services.", size: 12
        pdf.text "For questions, please contact: medical-cert@mdmat.org", size: 12
      end

      temp_file_path
    rescue StandardError => e
      Rails.logger.error "Error generating PDF for Application ID: #{application.id} - #{e.message}"
      nil
    end
  end

  # Create a notification record for tracking
  # @param admin [User] The admin who performed the action
  # @param rejection_reason [String] The reason for rejection
  # @param metadata [Hash] Additional metadata to include in the notification
  def create_notification_record(admin, rejection_reason, metadata = {})
    default_metadata = {
      medical_provider_name: application.medical_provider_name,
      rejection_reason: rejection_reason,
      notification_methods: notification_methods
    }

    NotificationService.create_and_deliver!(
      type: 'medical_certification_rejected',
      recipient: application.user,
      actor: admin,
      notifiable: application,
      metadata: default_metadata.merge(metadata),
      channel: :email
    )
  end

  # Get the contact methods that were available for the medical provider
  # @return [Array<String>] The available notification methods
  def notification_methods
    methods = []
    methods << 'fax' if application.medical_provider_fax.present?
    methods << 'email' if application.medical_provider_email.present?
    methods
  end
end
