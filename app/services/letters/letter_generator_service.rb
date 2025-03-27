# frozen_string_literal: true

module Letters
  class LetterGeneratorService
    attr_reader :template_type, :data, :constituent, :application

    def initialize(template_type:, constituent:, data: {}, application: nil)
      @template_type = template_type
      @data = data
      @constituent = constituent
      @application = application
    end

    def generate_pdf
      pdf = Prawn::Document.new do |doc|
        setup_document(doc)
        add_header(doc)
        add_date(doc)
        add_address(doc)
        add_salutation(doc)
        render_letter_content(doc)
        add_closing(doc)
        add_footer(doc)
        add_page_numbers(doc)
      end

      create_tempfile(pdf)
    end

    def queue_for_printing
      pdf_tempfile = generate_pdf
      letter_type = determine_letter_type

      print_queue_item = PrintQueueItem.new(
        constituent: constituent,
        application: application,
        letter_type: letter_type
      )

      # Attach the PDF to the queue item
      print_queue_item.pdf_letter.attach(
        io: File.open(pdf_tempfile.path),
        filename: "#{letter_type}_#{constituent.id}.pdf",
        content_type: 'application/pdf'
      )

      print_queue_item.save!
      pdf_tempfile.close
      pdf_tempfile.unlink

      print_queue_item
    end

    private

    def setup_document(pdf)
      pdf.font_size 11
    end

    def add_header(pdf)
      logo_path = Rails.root.join('app', 'assets', 'images', 'mat_logo.png')
      pdf.image(logo_path.to_s, width: 150) if File.exist?(logo_path)
      pdf.move_down 20
      pdf.font_size 18
      pdf.text letter_title, style: :bold, align: :center
      pdf.move_down 20
      pdf.font_size 11
    end

    def add_date(pdf)
      date_str = Time.current.strftime('%B %d, %Y')
      pdf.text "Date: #{date_str}", align: :right
      pdf.move_down 10
    end

    def add_address(pdf)
      address_lines = [
        constituent.full_name,
        constituent.physical_address_1,
        (constituent.physical_address_2 if constituent.physical_address_2.present?),
        "#{constituent.city}, #{constituent.state} #{constituent.zip_code}"
      ].compact

      pdf.text address_lines.join("\n")
      pdf.move_down 20
    end

    def add_salutation(pdf)
      pdf.text "Dear #{constituent.first_name},"
      pdf.move_down 10
    end

    def add_closing(pdf)
      pdf.move_down 30
      pdf.text 'Sincerely,'
      pdf.move_down 15
      pdf.text 'Maryland Accessible Telecommunications'
      pdf.text 'Customer Service Team'
    end

    def add_footer(pdf)
      pdf.move_down 50
      pdf.font_size 8
      pdf.stroke_horizontal_rule
      pdf.move_down 10
      pdf.text 'Maryland Accessible Telecommunications | 123 Main Street, Baltimore, MD 21201', align: :center
      pdf.text 'Phone: 555-123-4567 | Email: more.info@maryland.gov | Website: mdmat.org', align: :center
    end

    def add_page_numbers(pdf)
      pdf.number_pages 'Page <page> of <total>',
                       {
                         at: [pdf.bounds.right - 150, 0],
                         width: 150,
                         align: :right,
                         page_filter: :all,
                         start_count_at: 1
                       }
    end

    def create_tempfile(pdf)
      tempfile = Tempfile.new(['letter', '.pdf'])
      tempfile.binmode
      tempfile.write(pdf.render)
      tempfile.rewind
      tempfile
    end

    def letter_title
      case template_type
      when 'account_created'
        'Your Maryland Accessible Telecommunications Account'
      when 'registration_confirmation'
        'Welcome to the Maryland Accessible Telecommunications Program'
      when 'proof_rejected'
        if data[:proof_type] == 'income'
          'Income Verification Document Follow-up Required'
        else
          'Residency Verification Document Follow-up Required'
        end
      when 'income_threshold_exceeded'
        'Income Eligibility Review'
      when 'application_approved'
        'Application Approval Notification'
      when 'proof_approved'
        'Document Verification Approved'
      when 'max_rejections_reached'
        'Important Application Status Update'
      when 'proof_submission_error'
        'Document Submission Error'
      when 'evaluation_submitted'
        'Evaluation Submission Confirmation'
      else
        'Important Maryland Accessible Telecommunications Notice'
      end
    end

    def render_letter_content(pdf)
      case template_type
      when 'account_created'
        render_account_created_letter(pdf)
      when 'registration_confirmation'
        render_registration_confirmation_letter(pdf)
      when 'proof_rejected'
        render_proof_rejected_letter(pdf)
      when 'income_threshold_exceeded'
        render_income_threshold_exceeded_letter(pdf)
      when 'application_approved'
        render_application_approved_letter(pdf)
      when 'proof_approved'
        render_proof_approved_letter(pdf)
      when 'max_rejections_reached'
        render_max_rejections_reached_letter(pdf)
      when 'proof_submission_error'
        render_proof_submission_error_letter(pdf)
      when 'evaluation_submitted'
        render_evaluation_submitted_letter(pdf)
      else
        render_general_notification_letter(pdf)
      end
    end

    def render_account_created_letter(pdf)
      pdf.text 'We are pleased to inform you that your Maryland Accessible Telecommunications account has been created successfully. Your account provides access to our services and resources designed to improve telecommunications accessibility.'
      pdf.move_down 10
      pdf.text 'Account Details:', style: :bold
      pdf.move_down 5
      pdf.text "Username/Email: #{constituent.email}"
      pdf.text "Temporary Password: #{data[:temp_password]}"
      pdf.move_down 10
      pdf.text 'For security reasons, you will be required to change your password when you first log in. Please visit our website at mdmat.org to access your account.'
      pdf.move_down 10
      pdf.text "If you have any questions or need assistance, please don't hesitate to contact our customer service team."
    end

    def render_proof_rejected_letter(pdf)
      proof_type = data[:proof_type].to_s.titleize
      pdf.text "We have reviewed the #{proof_type} verification document you submitted for your Maryland Accessible Telecommunications application. Unfortunately, we are unable to accept the document you provided for the following reason:"
      pdf.move_down 10
      pdf.stroke_rounded_rectangle [0, pdf.cursor], pdf.bounds.width, 60, 5
      pdf.move_down 10
      pdf.indent(10) do
        pdf.move_down 10
        pdf.text data[:rejection_reason].to_s, style: :bold
        pdf.move_down 5
        pdf.text data[:rejection_notes].to_s if data[:rejection_notes].present?
      end
      pdf.move_down 20
      pdf.text "Please submit a new #{proof_type.downcase} verification document through one of the following methods:"
      pdf.move_down 5
      pdf.indent(10) do
        pdf.text '• Online: Log in to your account at mdmat.org and upload the document'
        pdf.text '• Email: Send to documents@mat.md.gov with your application ID in the subject line'
        pdf.text '• Mail: Send to our office at 123 Main Street, Baltimore, MD 21201'
      end
      pdf.move_down 10
      pdf.text 'If you have any questions or need assistance, please contact our customer service team at 555-123-4567.'
    end

    def render_income_threshold_exceeded_letter(pdf)
      pdf.text 'We have reviewed your application for Maryland Accessible Telecommunications services. Based on the income information you provided, we have determined that your household income exceeds our current eligibility threshold.'
      pdf.move_down 10
      pdf.text 'Program Eligibility Requirements:', style: :bold
      pdf.move_down 5
      pdf.text 'To qualify for our program, household income must be at or below 300% of the Federal Poverty Guidelines. According to the information you provided, your household income is above this threshold.'
      pdf.move_down 10
      pdf.text 'Appeal Process:', style: :bold
      pdf.move_down 5
      pdf.text 'If you believe this determination is incorrect, you may appeal this decision by submitting additional documentation to verify your income within 30 days. Please visit our website or contact our office for more information about the appeal process.'
      pdf.move_down 10
      pdf.text 'Alternative Resources:', style: :bold
      pdf.move_down 5
      pdf.text 'We encourage you to explore other resources that may be available to you. Please visit our website for information about alternative programs and resources that provide telecommunications assistance.'
    end

    def render_application_approved_letter(pdf)
      pdf.text 'Congratulations! We are pleased to inform you that your application for Maryland Accessible Telecommunications services has been approved.'
      pdf.move_down 10
      pdf.text 'Next Steps:', style: :bold
      pdf.move_down 5
      pdf.text 'A representative will contact you within 5-7 business days to schedule an evaluation to determine the equipment and services that will best meet your needs. This evaluation can take place at your home or at one of our evaluation centers, based on your preference.'
      pdf.move_down 10
      pdf.text 'What to Expect:', style: :bold
      pdf.move_down 5
      pdf.text 'During the evaluation, our specialist will assess your telecommunications needs and demonstrate various equipment options. They will provide recommendations and assist you in selecting the most appropriate equipment.'
      pdf.move_down 10
      pdf.text 'If you have any questions or need to reschedule your evaluation, please contact our office at 555-123-4567.'
    end

    def render_registration_confirmation_letter(pdf)
      render_introduction(pdf)
      render_program_overview(pdf)
      render_next_steps(pdf)
      render_application_details(pdf)
      render_available_products(pdf)
      render_authorized_retailers(pdf)
      render_contact_info(pdf)
    end

    def render_general_notification_letter(pdf)
      pdf.text 'This letter is to inform you about important information regarding your Maryland Accessible Telecommunications account or application.'
      pdf.move_down 10
      if data[:message].present?
        pdf.text data[:message]
      else
        pdf.text 'Please contact our customer service team at 555-123-4567 for more information or to discuss any questions you may have about your account or services.'
      end
    end

    def determine_letter_type
      case template_type
      when 'account_created'
        :account_created
      when 'registration_confirmation'
        :registration_confirmation
      when 'proof_rejected'
        data[:proof_type] == 'income' ? :income_proof_rejected : :residency_proof_rejected
      when 'income_threshold_exceeded'
        :income_threshold_exceeded
      when 'application_approved'
        :application_approved
      when 'proof_approved'
        :proof_approved
      when 'max_rejections_reached'
        :max_rejections_reached
      when 'proof_submission_error'
        :proof_submission_error
      when 'evaluation_submitted'
        :evaluation_submitted
      else
        :other_notification
      end
    end

    def render_introduction(pdf)
      pdf.text 'Thank you for registering with the Maryland Accessible Telecommunications Program. We\'re here to help Maryland residents with hearing loss, vision loss, mobility impairments, speech impairments, and cognitive impairments access telecommunications devices that meet their needs.'
      pdf.move_down 15
    end

    def render_program_overview(pdf)
      pdf.text 'PROGRAM OVERVIEW', style: :bold
      pdf.move_down 5
      pdf.text 'Our program provides vouchers to eligible Maryland residents to purchase accessible telecommunications products. You may be eligible if your household income is less than 400% of the federal poverty level for your family size.'
      pdf.move_down 15
    end

    def render_next_steps(pdf)
      pdf.text 'NEXT STEPS', style: :bold
      pdf.move_down 5
      pdf.text 'To apply for assistance:'
      pdf.move_down 5
      pdf.indent(10) do
        pdf.text '1. Visit your dashboard to access your profile at mdmat.org/dashboard'
        pdf.text '2. Start a new application'
        pdf.text '3. Complete all required information, including proofs of residency and income, and information for your medical provider'
        pdf.text '4. Submit your application for review'
      end
      pdf.move_down 10
    end

    def render_application_details(pdf)
      pdf.text "Once your application is approved, you'll receive a voucher that can be used to purchase eligible devices, along with information about available devices, vendors to purchase through, and resources for training."
      pdf.move_down 15
    end

    def render_available_products(pdf)
      pdf.text 'AVAILABLE PRODUCTS', style: :bold
      pdf.move_down 5
      pdf.text 'We offer a variety of accessible telecommunications products for a range of disabilities, including:'
      pdf.move_down 5
      pdf.indent(10) do
        pdf.text '• Amplified phones for individuals with hearing loss'
        pdf.text '• Specialized landline phones for individuals with vision loss or hearing loss'
        pdf.text '• Smartphones (iPhone, iPad, Pixel) with accessibility features and applications to support multiple types of disabilities'
        pdf.text '• Braille and speech devices for individuals with speech differences'
        pdf.text '• Communication aids for cognitive, memory or speech differences'
        pdf.text '• Visual, audible, and tactile emergency alert systems'
      end
      pdf.move_down 15
    end

    def render_authorized_retailers(pdf)
      pdf.text 'AUTHORIZED RETAILERS', style: :bold
      pdf.move_down 5
      pdf.text "Once your application is approved, you'll receive a voucher to purchase eligible devices through our authorized vendors."
      if data[:active_vendors].present?
        pdf.move_down 5
        pdf.text 'You can redeem your voucher at any of these authorized vendors:'
        pdf.move_down 5
        data[:active_vendors].each do |vendor|
          vendor_info = "• #{vendor.business_name || vendor.full_name}"
          vendor_info += " - Website: #{vendor.website_url}" if vendor.website_url.present?
          vendor_info += " - Phone: #{vendor.phone}" if vendor.phone.present?
          pdf.text vendor_info
        end
      end
      pdf.move_down 15
    end

    def render_contact_info(pdf)
      pdf.text "If you have any questions about our program or need assistance with your application, please don't hesitate to contact our customer service team at more.info@maryland.gov or 410-697-9700."
    end

    def render_proof_approved_letter(pdf)
      proof_type = data[:proof_type].to_s.titleize

      pdf.text 'Thank you for submitting your application to the Maryland Accessible Telecommunications program. We appreciate your interest in our services and look forward to assisting you.'
      pdf.move_down 10

      pdf.text 'Documentation Approved', style: :bold
      pdf.move_down 5

      pdf.text "We have reviewed and approved your #{proof_type} documentation."
      pdf.move_down 10

      if data[:all_proofs_approved]
        pdf.text 'Great news! All your required documentation has been approved. We will now proceed with requesting certification from your healthcare provider.'
      end

      pdf.move_down 10
      pdf.text "What's Next:", style: :bold
      pdf.move_down 5
      pdf.text 'Our team will continue to process your application and will contact you if any additional information is needed. You can also check the status of your application by logging into your account at mdmat.org or contacting our customer service team.'
    end

    def render_max_rejections_reached_letter(pdf)
      pdf.text 'We regret to inform you that your Maryland Accessible Telecommunications application cannot proceed at this time.'
      pdf.move_down 10

      pdf.text 'Application Status:', style: :bold
      pdf.move_down 5
      pdf.text 'After multiple reviews, we have been unable to approve the verification documents you submitted. The maximum number of submission attempts has been reached for this application.'
      pdf.move_down 10

      if data[:reapply_date].present?
        pdf.text 'Reapplication Information:', style: :bold
        pdf.move_down 5
        pdf.text "You may submit a new application on or after #{data[:reapply_date].strftime('%B %d, %Y')}. Please ensure that your new application includes all required documentation that meets our program requirements."
      end

      pdf.move_down 10
      pdf.text 'If you need assistance understanding our documentation requirements or have questions about alternative programs, please contact our customer service team at 555-123-4567.'
    end

    def render_proof_submission_error_letter(pdf)
      pdf.text 'We encountered an error while processing your document submission for your Maryland Accessible Telecommunications application.'
      pdf.move_down 10

      pdf.text 'Error Details:', style: :bold
      pdf.move_down 5

      error_message = data[:message] || 'There was a technical issue processing your document'
      pdf.text error_message

      pdf.move_down 10
      pdf.text 'Next Steps:', style: :bold
      pdf.move_down 5
      pdf.text 'Please try submitting your document again using one of these methods:'
      pdf.move_down 5
      pdf.indent(10) do
        pdf.text '• Online: Log in to your account at mdmat.org and upload the document'
        pdf.text '• Email: Send to documents@mat.md.gov with your application ID in the subject line'
        pdf.text '• Mail: Send to our office at 123 Main Street, Baltimore, MD 21201'
      end

      pdf.move_down 10
      pdf.text 'If you continue to experience issues, please contact our technical support team at 555-123-4567 for assistance.'
    end

    def render_evaluation_submitted_letter(pdf)
      pdf.text 'This letter confirms that your evaluation for the Maryland Accessible Telecommunications Program has been submitted.'
      pdf.move_down 10

      if data[:evaluation].present?
        pdf.text 'Evaluation Details:', style: :bold
        pdf.move_down 5
        pdf.text "Evaluation Date: #{data[:evaluation].created_at.strftime('%B %d, %Y')}"

        if data[:evaluation].equipment_recommendations.present?
          pdf.move_down 10
          pdf.text 'Recommended Equipment:', style: :bold
          pdf.move_down 5

          data[:evaluation].equipment_recommendations.each do |recommendation|
            pdf.text "• #{recommendation}"
          end
        end
      end

      pdf.move_down 10
      pdf.text 'Next Steps:', style: :bold
      pdf.move_down 5
      pdf.text 'You will receive a voucher for approved equipment within 10-15 business days. The voucher will include details about how to redeem it with our authorized vendors.'
      pdf.move_down 10
      pdf.text 'If you have any questions about the evaluation or the equipment recommendations, please contact our customer service team at 555-123-4567.'
    end
  end
end
