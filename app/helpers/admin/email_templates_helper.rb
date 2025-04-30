# frozen_string_literal: true

module Admin
  module EmailTemplatesHelper
    # Provides sample data for rendering email template previews or tests.
    # Returns a hash with string keys matching the %{variable_name} placeholders.
    def sample_data_for_template(template_name) # rubocop:disable Metrics/MethodLength
      base_data = {
        'header_text' => render(partial: 'shared/mailers/header', formats: [:text], locals: { title: 'Sample Email Title' }),
        'footer_text' => render(partial: 'shared/mailers/footer', formats: [:text], locals: { show_automated_message: true }),
        'header_logo_url' => asset_url('TAM_color.png'),
        'header_subtitle' => 'Sample Subtitle',
        'footer_contact_email' => 'support@example.com',
        'footer_website_url' => 'http://example.com',
        'footer_show_automated_message' => true,
        'organization_name' => 'Maryland Accessible Telecommunications',
        'sign_in_url' => 'http://example.com/sign_in',
        'dashboard_url' => 'http://example.com/dashboard',
        'admin_dashboard_url' => 'http://example.com/admin/dashboard',
        'vendor_portal_url' => 'http://example.com/vendor',
        'application_id' => '12345',
        'user_first_name' => 'Alex',
        'user_email' => 'alex@example.com',
        'constituent_first_name' => 'Jamie',
        'constituent_full_name' => 'Jamie Doe',
        'constituent_dob_formatted' => 'January 15, 1985',
        'constituent_address_formatted' => "123 Main St\nAnytown, MD 12345",
        'constituent_phone_formatted' => '555-123-4567',
        'constituent_email' => 'jamie.doe@example.com',
        'admin_first_name' => 'Admin User',
        'evaluator_full_name' => 'Dr. Evaluation Expert',
        'trainer_full_name' => 'Training Specialist',
        'vendor_business_name' => 'Example Vendor Inc.',
        'timestamp_formatted' => Time.current.strftime('%B %d, %Y at %I:%M %p %Z'),
        'submission_date_formatted' => Date.current.strftime('%B %d, %Y'),
        'expiration_date_formatted' => (Date.current + 3.months).strftime('%B %d, %Y'),
        'reapply_date_formatted' => (Date.current + 6.months).strftime('%B %d, %Y'),
        'transaction_date_formatted' => Date.current.strftime('%B %d, %Y'),
        'period_start_formatted' => (Date.current - 1.month).beginning_of_month.strftime('%B %d, %Y'),
        'period_end_formatted' => (Date.current - 1.month).end_of_month.strftime('%B %d, %Y'),
        'status_box_text' => 'INFO: Sample Status Message',
        'status_box_warning_text' => 'WARNING: Sample Warning Message',
        'status_box_info_text' => 'INFO: Sample Info Message',
        'error_message' => 'A sample error occurred during processing.',
        'rejection_reason' => 'Information provided was incomplete.',
        'additional_instructions' => 'Please provide documents X, Y, and Z.',
        'remaining_attempts' => 2,
        'remaining_attempts_message_text' => 'You have 2 attempts remaining.',
        'archived_message_text' => 'Your application has been archived.',
        'default_options_text' => 'Please sign in to review.',
        'all_proofs_approved_message_text' => 'All required proofs have been approved!',
        'active_vendors_text_list' => "- Vendor A\n- Vendor B",
        'stale_reviews_count' => 5,
        'stale_reviews_text_list' => "- App 1\n- App 2\n- App 3\n- App 4\n- App 5", # Placeholder
        'constituent_disabilities_text_list' => "- Disability 1\n- Disability 2", # Placeholder
        'evaluators_evaluation_url' => 'http://example.com/evaluators/evaluations/1',
        'verification_url' => 'http://example.com/identity/email_verifications/TOKEN',
        'reset_url' => 'http://example.com/identity/password_resets/TOKEN',
        'invoice_number' => 'INV-2025-001',
        'total_amount_formatted' => '$1,234.56',
        'transactions_text_list' => "- Txn 1: $100\n- Txn 2: $200", # Placeholder
        'gad_invoice_reference' => 'GADREF98765',
        'check_number' => 'CHK1001',
        'days_until_expiry' => 30,
        'vendor_association_message' => 'Your association is active.',
        'voucher_code' => 'VOUCHER123XYZ',
        'initial_value_formatted' => '$500.00',
        'unused_value_formatted' => '$150.00',
        'remaining_balance_formatted' => '$350.00',
        'validity_period_months' => 6,
        'minimum_redemption_amount_formatted' => '$25.00',
        'transaction_amount_formatted' => '$150.00',
        'transaction_reference_number' => 'TXNREFABCDE',
        'transaction_history_text' => "- Redeemed $100 at Vendor A\n- Redeemed $50 at Vendor B", # Placeholder
        'remaining_value_message_text' => 'Your remaining balance is $350.00.',
        'fully_redeemed_message_text' => 'This voucher has been fully redeemed.',
        'download_form_url' => 'http://example.com/forms/medical_cert.pdf',
        'request_count_message' => '(Request #1)',
        'temp_password' => 'temporaryP@ssw0rd',
        'household_size' => 4,
        'annual_income_formatted' => '$45,000.00',
        'threshold_formatted' => '$55,000.00',
        'proof_type_formatted' => 'Income Verification',
        'additional_notes' => 'These are some additional notes.'
      }

      # Add template-specific overrides or additions here if needed
      case template_name.to_sym
      when :vendor_notifications_invoice_generated
        base_data.merge({
                          'header_title' => 'Vendor Notification: Invoice Generated',
                          'vendor_business_name' => 'Baltimore Accessible Tech Solutions',
                          'vendor_contact_name' => 'Morgan Johnson',
                          'vendor_contact_email' => 'morgan@baltimoreats.com',
                          'invoice_number' => 'INV-2025-042',
                          'period_start_formatted' => (Date.current - 1.month).beginning_of_month.strftime('%B %d, %Y'),
                          'period_end_formatted' => (Date.current - 1.month).end_of_month.strftime('%B %d, %Y'),
                          'total_amount_formatted' => '$1,875.50',
                          'transactions_text_list' => "- Voucher #V0012345: $550.00\n- Voucher #V0012346: $725.50\n- Voucher #V0012347: $600.00"
                        })
      when :vendor_notifications_payment_issued
        base_data.merge({
                          'header_title' => 'Vendor Notification: Payment Issued',
                          'vendor_business_name' => 'Baltimore Accessible Tech Solutions',
                          'vendor_contact_name' => 'Morgan Johnson',
                          'vendor_contact_email' => 'morgan@baltimoreats.com',
                          'invoice_number' => 'INV-2025-042',
                          'total_amount_formatted' => '$1,875.50',
                          'gad_invoice_reference' => 'GAD-2025-X9874',
                          'check_number' => 'CHK-58742'
                        })
      when :vendor_notifications_w9_approved, :vendor_notifications_w9_rejected, :vendor_notifications_w9_expired, :vendor_notifications_w9_expiring_soon
        base_data.merge({
                          'header_title' => "Vendor Notification: #{template_name.to_s.gsub('vendor_notifications_', '').humanize}",
                          'vendor_business_name' => 'Baltimore Accessible Tech Solutions',
                          'vendor_contact_name' => 'Morgan Johnson',
                          'vendor_contact_email' => 'morgan@baltimoreats.com'
                        })
      when :email_header_text
        base_data.merge({
                          'title' => 'Maryland Accessible Telecommunications',
                          'subtitle' => 'Important Notification',
                          'logo_url' => asset_url('TAM_color.png')
                        })
      when :email_footer_text
        base_data.merge({
                          'organization_name' => 'Maryland Accessible Telecommunications',
                          'contact_email' => 'support@mdmat.org',
                          'website_url' => 'https://mdmat.org',
                          'show_automated_message' => true
                        })
      when :application_notifications_account_created
        base_data.merge({
                          'header_title' => 'Your MAT Application Account',
                          'header_text' => 'Maryland Accessible Telecommunications',
                          'footer_text' => "Contact us at support@mdmat.org\nMaryland Accessible Telecommunications",
                          'user_full_name' => 'Jamie Doe',
                          'constituent_first_name' => 'Jamie',
                          'constituent_email' => 'jamie.doe@example.com',
                          'temp_password' => 'Temp123!',
                          'sign_in_url' => 'http://example.com/sign_in',
                          'title' => 'Account Created',
                          'show_automated_message' => true
                        })
      when :application_notifications_income_threshold_exceeded
        base_data.merge({
                          'header_title' => 'Application Update: Income Threshold',
                          'header_text' => 'Maryland Accessible Telecommunications',
                          'footer_text' => "Contact us at support@mdmat.org\nMaryland Accessible Telecommunications",
                          'constituent_first_name' => 'Jamie',
                          'household_size' => 4,
                          'annual_income_formatted' => '$45,000.00',
                          'threshold_formatted' => '$35,000.00',
                          'status_box_text' => 'ERROR: Income Exceeds Limit',
                          'title' => 'Income Threshold Exceeded',
                          'show_automated_message' => true
                        })
      when :application_notifications_registration_confirmation
        base_data.merge({
                          'header_title' => 'Registration Confirmation',
                          'header_text' => 'Maryland Accessible Telecommunications',
                          'footer_text' => "Contact us at support@mdmat.org\nMaryland Accessible Telecommunications",
                          'user_full_name' => 'Jamie Doe',
                          'dashboard_url' => 'http://example.com/dashboard',
                          'new_application_url' => 'http://example.com/applications/new',
                          'active_vendors_text_list' => "- ABC Telecommunications\n- XYZ Assistive Devices\n- Maryland Tech Solutions",
                          'title' => 'Registration Confirmation',
                          'show_automated_message' => true
                        })
      when :application_notifications_proof_submission_error
        base_data.merge({
                          'header_title' => 'Proof Submission Error',
                          'message' => 'There was an error processing your submission. The file format is not supported.'
                        })
      when :medical_provider_certification_submission_error
        base_data.merge({
                          'header_title' => 'Certification Submission Error',
                          'medical_provider_email' => 'doctor@example.com'
                        })
      when :training_session_notifications_training_scheduled
        base_data.merge({
                          'header_title' => 'Training Session Scheduled',
                          'scheduled_date_formatted' => (Date.current + 2.weeks).strftime('%B %d, %Y'),
                          'scheduled_time_formatted' => '10:00 AM - 11:30 AM',
                          'scheduled_date_time_formatted' => "#{(Date.current + 2.weeks).strftime('%B %d, %Y')} at 10:00 AM - 11:30 AM",
                          'trainer_email' => 'trainer@example.com',
                          'trainer_phone_formatted' => '555-987-6543',
                          'support_email' => 'training@example.com'
                        })
      when :training_session_notifications_training_cancelled
        base_data.merge({
                          'header_title' => 'Training Session Cancelled',
                          'scheduled_date_time_formatted' => "#{(Date.current + 2.weeks).strftime('%B %d, %Y')} at 10:00 AM - 11:30 AM",
                          'support_email' => 'training@example.com'
                        })
      when :training_session_notifications_training_completed
        base_data.merge({
                          'header_title' => 'Training Session Completed',
                          'completed_date_formatted' => Date.current.strftime('%B %d, %Y'),
                          'trainer_email' => 'trainer@example.com',
                          'trainer_phone_formatted' => '555-987-6543'
                        })
      when :training_session_notifications_training_no_show
        base_data.merge({
                          'header_title' => 'Training Session Missed',
                          'scheduled_date_time_formatted' => "#{(Date.current - 1.day).strftime('%B %d, %Y')} at 10:00 AM - 11:30 AM",
                          'support_email' => 'training@example.com'
                        })
      # Removed duplicate case condition for :vendor_notifications_w9_expired
      when :voucher_notifications_voucher_redeemed
        base_data.merge({
                          'header_title' => 'Voucher Successfully Redeemed',
                          'redeemed_value_formatted' => '$350.00',
                          'transaction_amount_formatted' => '$150.00',
                          'remaining_balance_formatted' => '$350.00'
                        })
      when :admin_notifications_stale_reviews_summary
        base_data.merge({
                          'header_title' => 'Stale Reviews Summary',
                          'admin_full_name' => 'Admin User'
                        })
      # Add cases for all other template names...
      else
        base_data # Return base data if no specific overrides
      end
    end
  end
end
