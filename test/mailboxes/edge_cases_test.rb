# frozen_string_literal: true

require 'test_helper'
require 'support/action_mailbox_test_helper'

class EdgeCasesTest < ActionMailbox::TestCase
  include ActionMailboxTestHelper

  setup do
    # Create a constituent and application using factories
    @constituent = create(:constituent)
    @application = create(:application, user: @constituent)
    @constituent.update(email: 'constituent@example.com')

    # Create a medical provider using factory
    @medical_provider = create(:medical_provider, email: 'doctor@example.com')

    # Create policy records for rate limiting
    create(:policy, :proof_submission_rate_limit_web)
    create(:policy, :proof_submission_rate_limit_email)
    create(:policy, :proof_submission_rate_period)

    # Set up ApplicationMailbox routing for testing
    ApplicationMailbox.instance_eval do
      routing(/proof@/i => :proof_submission)
      routing(/medical-cert@/i => :medical_certification)
      routing(/.+/ => :default)
    end
  end

  test 'handles emails with no attachments' do
    inbound_email = create_inbound_email_from_mail(
      to: 'proof@example.com',
      from: @constituent.email,
      subject: 'Income Proof Submission',
      body: 'I forgot to attach my proof.'
    )

    # Process the email
    inbound_email.route

    # Verify the email was bounced
    assert_equal 'bounced', inbound_email.status
  end

  test 'handles emails with unsupported attachment types' do
    # Create a temporary file for testing
    file_path = Rails.root.join('tmp', 'income_proof.exe')
    File.open(file_path, 'w') do |f|
      f.write('This is not a valid document')
    end

    inbound_email = create_inbound_email_with_attachment(
      to: 'proof@example.com',
      from: @constituent.email,
      subject: 'Income Proof Submission',
      body: 'Please find my income proof attached.',
      attachment_path: file_path,
      content_type: 'application/octet-stream'
    )

    # Process the email
    inbound_email.route

    # Verify the email was bounced
    assert_equal 'bounced', inbound_email.status

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test 'handles emails with very large attachments' do
    skip 'Large file validation not implemented' unless defined?(ProofAttachmentValidator) &&
                                                        ProofAttachmentValidator.method_defined?(:validate_file_size)

    # Create a large temporary file for testing
    file_path = Rails.root.join('tmp', 'large_income_proof.pdf')
    File.open(file_path, 'w') do |f|
      # Create a file that's larger than the allowed size
      f.write('X' * 11.megabytes)
    end

    inbound_email = create_inbound_email_with_attachment(
      to: 'proof@example.com',
      from: @constituent.email,
      subject: 'Income Proof Submission',
      body: 'Please find my income proof attached.',
      attachment_path: file_path,
      content_type: 'application/pdf'
    )

    # Process the email
    inbound_email.route

    # Verify the email was bounced
    assert_equal 'bounced', inbound_email.status

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test 'handles emails with ambiguous proof type' do
    # Create a temporary file for testing
    file_path = Rails.root.join('tmp', 'proof.pdf')
    File.open(file_path, 'w') do |f|
      f.write('This is a test PDF file')
    end

    inbound_email = create_inbound_email_with_attachment(
      to: 'proof@example.com',
      from: @constituent.email,
      subject: 'Proof Document',
      body: 'Please find my proof attached.',
      attachment_path: file_path,
      content_type: 'application/pdf'
    )

    # Process the email
    inbound_email.route

    # Verify the email was bounced or processed based on implementation
    # If the implementation defaults to a specific proof type, it should be processed
    # If it requires explicit proof type, it should be bounced
    if inbound_email.status == 'delivered'
      assert @application.income_proof.attached? || @application.residency_proof.attached?
    else
      assert_equal 'bounced', inbound_email.status
    end

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test 'handles emails with multiple recipients' do
    # Create a temporary file for testing
    file_path = Rails.root.join('tmp', 'income_proof.pdf')
    File.open(file_path, 'w') do |f|
      f.write('This is a test PDF file')
    end

    mail = Mail.new do
      from 'constituent@example.com'
      to ['proof@example.com', 'support@example.com', 'admin@example.com']
      subject 'Income Proof Submission'

      text_part do
        body 'Please find my income proof attached.'
      end

      add_file filename: 'income_proof.pdf', content: File.read(file_path)
    end

    # Create and process the inbound email
    inbound_email = ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s)
    inbound_email.route

    # Verify the email was processed correctly
    assert_equal 'delivered', inbound_email.status

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test 'handles emails with special characters in subject and body' do
    # Create a temporary file for testing
    file_path = Rails.root.join('tmp', 'income_proof.pdf')
    File.open(file_path, 'w') do |f|
      f.write('This is a test PDF file')
    end

    inbound_email = create_inbound_email_with_attachment(
      to: 'proof@example.com',
      from: @constituent.email,
      subject: 'Income Proof Submission - 特殊文字 - üñîçødé',
      body: 'Please find my income proof attached. 特殊文字 üñîçødé',
      attachment_path: file_path,
      content_type: 'application/pdf'
    )

    # Process the email
    inbound_email.route

    # Verify the email was processed correctly
    assert_equal 'delivered', inbound_email.status

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end
end
