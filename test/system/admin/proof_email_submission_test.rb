# frozen_string_literal: true

require 'application_system_test_case'
require 'support/action_mailbox_test_helper'

module Admin
  class ProofEmailSubmissionTest < ApplicationSystemTestCase
    include ActionMailboxTestHelper

    setup do
      # Create users and application using factories
      @admin = create(:admin)
      @constituent = create(:constituent)
      @application = create(:application, user: @constituent)
      @constituent.update(email: 'constituent@example.com')

      # Set up ApplicationMailbox routing for testing
      ApplicationMailbox.instance_eval do
        routing(/proof@/i => :proof_submission)
      end

      # Log in as admin
      visit new_session_path
      fill_in 'Email', with: @admin.email
      fill_in 'Password', with: 'password123'
      click_on 'Sign in'
    end

    test 'admin can view and approve proof submitted via email' do
      # Create a temporary file for testing
      file_path = Rails.root.join('tmp', 'income_proof.pdf')
      File.open(file_path, 'w') do |f|
        f.write('This is a test PDF file')
      end

      # Create and process an inbound email
      inbound_email = create_inbound_email_with_attachment(
        to: 'proof@example.com',
        from: @constituent.email,
        subject: 'Income Proof Submission',
        body: 'Please find my income proof attached.',
        attachment_path: file_path,
        content_type: 'application/pdf'
      )

      inbound_email.route

      # Visit the application page
      visit admin_application_path(@application)

      # Check if the proof is visible
      assert_text 'Income Proof'
      assert_text 'Submitted via email'

      # Approve the proof
      click_on 'Review'
      click_on 'Approve'
      fill_in 'Notes', with: 'Proof looks good'
      click_on 'Submit Review'

      # Verify the proof was approved
      assert_text 'Proof approved successfully'

      # Clean up
      File.delete(file_path) if File.exist?(file_path)
    end

    test 'admin can view and reject proof submitted via email' do
      # Create a temporary file for testing
      file_path = Rails.root.join('tmp', 'income_proof.pdf')
      File.open(file_path, 'w') do |f|
        f.write('This is a test PDF file')
      end

      # Create and process an inbound email
      inbound_email = create_inbound_email_with_attachment(
        to: 'proof@example.com',
        from: @constituent.email,
        subject: 'Income Proof Submission',
        body: 'Please find my income proof attached.',
        attachment_path: file_path,
        content_type: 'application/pdf'
      )

      inbound_email.route

      # Visit the application page
      visit admin_application_path(@application)

      # Check if the proof is visible
      assert_text 'Income Proof'
      assert_text 'Submitted via email'

      # Reject the proof
      click_on 'Review'
      click_on 'Reject'
      select 'Illegible', from: 'Reason'
      fill_in 'Notes', with: 'Cannot read the document'
      click_on 'Submit Review'

      # Verify the proof was rejected
      assert_text 'Proof rejected successfully'

      # Clean up
      File.delete(file_path) if File.exist?(file_path)
    end

    test 'admin can view multiple attachments from a single email' do
      # Create temporary files for testing
      file_path1 = Rails.root.join('tmp', 'income_proof1.pdf')
      file_path2 = Rails.root.join('tmp', 'income_proof2.pdf')

      File.open(file_path1, 'w') { |f| f.write('This is test file 1') }
      File.open(file_path2, 'w') { |f| f.write('This is test file 2') }

      # Create a raw email with multiple attachments
      mail = Mail.new do
        from @constituent.email
        to 'proof@example.com'
        subject 'Income Proof Submission'

        text_part do
          body 'Please find my income proofs attached.'
        end

        add_file filename: 'income_proof1.pdf', content: File.read(file_path1)
        add_file filename: 'income_proof2.pdf', content: File.read(file_path2)
      end

      # Create and process the inbound email
      inbound_email = ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s)
      inbound_email.route

      # Visit the application page
      visit admin_application_path(@application)

      # Check if both attachments are visible
      assert_text 'Income Proof'
      assert_text 'Submitted via email'
      assert_text 'income_proof1.pdf'
      assert_text 'income_proof2.pdf'

      # Clean up
      File.delete(file_path1) if File.exist?(file_path1)
      File.delete(file_path2) if File.exist?(file_path2)
    end
  end
end
