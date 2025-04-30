# frozen_string_literal: true

require 'test_helper'

module Letters
  class TextTemplateToPdfServiceTest < ActiveSupport::TestCase
    setup do
      @user = create(:constituent)
      @template = create(:email_template,
                         name: 'application_notifications_account_created',
                         subject: 'Your account has been created',
                         body: "Welcome to the service!\n\nYour username is %<email>s.\nYour temporary password is %<temp_password>s.\n\nPlease login soon.",
                         format: :text)
      @variables = {
        email: @user.email,
        temp_password: 'SecurePassword123'
      }
    end

    test 'generates PDF from database template' do
      service = TextTemplateToPdfService.new(
        template_name: 'application_notifications_account_created',
        recipient: @user,
        variables: @variables
      )

      pdf_file = service.generate_pdf

      # Basic checks that the PDF was generated
      assert pdf_file.is_a?(Tempfile)
      assert_match '%PDF', pdf_file.read[0, 10] # PDF files start with %PDF

      # Close the file to prevent resource leaks
      pdf_file.close
      pdf_file.unlink
    end

    test 'correctly substitutes variables in template' do
      service = TextTemplateToPdfService.new(
        template_name: 'application_notifications_account_created',
        recipient: @user,
        variables: @variables
      )

      # Test the private render_template_with_variables method
      rendered_content = service.send(:render_template_with_variables)

      # Check that variables were substituted
      assert_match @user.email, rendered_content
      assert_match 'SecurePassword123', rendered_content
      assert_no_match(/%\{email\}/, rendered_content)
      assert_no_match(/%\{temp_password\}/, rendered_content)
    end

    test 'returns nil when template not found' do
      service = TextTemplateToPdfService.new(
        template_name: 'non_existent_template',
        recipient: @user,
        variables: @variables
      )

      pdf_file = service.generate_pdf
      assert_nil pdf_file
    end

    test 'correctly queues item for printing' do
      service = TextTemplateToPdfService.new(
        template_name: 'application_notifications_account_created',
        recipient: @user,
        variables: @variables
      )

      # Mock the generate_pdf method to avoid actually generating a PDF
      pdf_mock = Tempfile.new(['test', '.pdf'])
      pdf_mock.write('%PDF-1.7 Test PDF') # Write valid PDF header
      pdf_mock.rewind

      service.stub(:generate_pdf, pdf_mock) do
        assert_difference 'PrintQueueItem.count', 1 do
          queue_item = service.queue_for_printing

          assert_equal @user, queue_item.constituent
          assert_equal 'application_notifications_account_created', queue_item.letter_type.to_s
          assert queue_item.pdf_letter.attached?
        end
      end

      # Clean up
      pdf_mock.close
      pdf_mock.unlink
    end
  end
end
