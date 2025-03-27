# frozen_string_literal: true

require 'test_helper'

class ProofSubmissionMailboxTest < ActionMailbox::TestCase
  setup do
    # Set up a constituent with an active application
    @constituent = users(:constituent_john)
    @application = applications(:one)

    # Ensure application status is appropriate for accepting proofs
    @application.update!(status: 'in_progress')

    # Set up policy limits for testing
    Policy.set('max_proof_rejections', 3) unless Policy.get('max_proof_rejections')

    # Create a test PDF file for attachment
    @pdf_content = 'Sample PDF content for testing'
    @pdf_file = Tempfile.new(['test', '.pdf'])
    @pdf_file.write(@pdf_content)
    @pdf_file.rewind
  end

  teardown do
    @pdf_file.close
    @pdf_file.unlink
  end

  test 'processes an email with attachment from known constituent' do
    # Track the event count before processing
    previous_event_count = Event.count

    # Process an inbound email
    receive_inbound_email_from_mail(
      to: MatVulcan::InboundEmailConfig.inbound_email_address,
      from: @constituent.email,
      subject: 'Income Proof Submission',
      body: 'Please find my proof attached.',
      attachments: {
        'proof.pdf' => @pdf_content
      }
    )

    # Verify events were created
    assert_equal previous_event_count + 2, Event.count
    submission_event = Event.order(created_at: :desc).offset(1).first
    processed_event = Event.order(created_at: :desc).first

    assert_equal 'proof_submission_received', submission_event.action
    assert_equal @constituent.id, submission_event.user_id
    assert_equal @application.id, submission_event.metadata['application_id']

    assert_equal 'proof_submission_processed', processed_event.action

    # Verify the proof was attached to the application with the right type
    @application.reload
    assert @application.proofs.income.exists?
    proof = @application.proofs.income.last
    assert_equal :email, proof.submission_method
    assert proof.metadata.key?('email_subject')
    assert proof.metadata.key?('inbound_email_id')
  end

  test 'bounces email from unknown sender' do
    # Should get bounced because the sender is not a recognized constituent
    assert_changes 'ActionMailer::Base.deliveries.size' do
      receive_inbound_email_from_mail(
        to: MatVulcan::InboundEmailConfig.inbound_email_address,
        from: 'unknown@example.com',
        subject: 'Income Proof',
        body: 'Proof attached.',
        attachments: {
          'proof.pdf' => @pdf_content
        }
      )
    end

    # Verify the bounce created an event
    latest_event = Event.last
    assert_equal 'proof_submission_constituent_not_found', latest_event.action
  end

  test 'bounces email from constituent without active application' do
    # Create a constituent without an active application
    constituent_without_app = users(:constituent_mark)

    # Ensure any applications are not in an active state
    constituent_without_app.applications.update_all(status: 'completed')

    assert_changes 'ActionMailer::Base.deliveries.size' do
      receive_inbound_email_from_mail(
        to: MatVulcan::InboundEmailConfig.inbound_email_address,
        from: constituent_without_app.email,
        subject: 'Income Proof',
        body: 'Proof attached.',
        attachments: {
          'proof.pdf' => @pdf_content
        }
      )
    end

    latest_event = Event.last
    assert_equal 'proof_submission_inactive_application', latest_event.action
  end

  test 'bounces email without attachments' do
    assert_changes 'ActionMailer::Base.deliveries.size' do
      receive_inbound_email_from_mail(
        to: MatVulcan::InboundEmailConfig.inbound_email_address,
        from: @constituent.email,
        subject: 'Income Proof',
        body: 'I forgot to attach the proof!'
      )
    end

    latest_event = Event.last
    assert_equal 'proof_submission_no_attachments', latest_event.action
  end

  test 'bounces email when max rejections reached' do
    # Update the application to have max rejections
    max_rejections = Policy.get('max_proof_rejections')
    @application.update(total_rejections: max_rejections)

    assert_changes 'ActionMailer::Base.deliveries.size' do
      receive_inbound_email_from_mail(
        to: MatVulcan::InboundEmailConfig.inbound_email_address,
        from: @constituent.email,
        subject: 'Income Proof',
        body: 'Please find my proof attached.',
        attachments: {
          'proof.pdf' => @pdf_content
        }
      )
    end

    latest_event = Event.last
    assert_equal 'proof_submission_max_rejections_reached', latest_event.action
  end

  test 'determines proof type from subject' do
    # Test with income in the subject
    receive_inbound_email_from_mail(
      to: MatVulcan::InboundEmailConfig.inbound_email_address,
      from: @constituent.email,
      subject: 'Income Proof Submission',
      body: 'Income proof attached.',
      attachments: {
        'proof.pdf' => @pdf_content
      }
    )

    @application.reload
    assert @application.proofs.income.where(submission_method: :email).exists?

    # Test with residency in the subject
    receive_inbound_email_from_mail(
      to: MatVulcan::InboundEmailConfig.inbound_email_address,
      from: @constituent.email,
      subject: 'Residency Proof Submission',
      body: 'Residency proof attached.',
      attachments: {
        'proof.pdf' => @pdf_content
      }
    )

    @application.reload
    assert @application.proofs.residency.where(submission_method: :email).exists?
  end

  test 'determines proof type from body when subject is ambiguous' do
    # Test with residency in the body but not subject
    receive_inbound_email_from_mail(
      to: MatVulcan::InboundEmailConfig.inbound_email_address,
      from: @constituent.email,
      subject: 'Proof documents',
      body: "I'm sending my residency proof as requested.",
      attachments: {
        'proof.pdf' => @pdf_content
      }
    )

    @application.reload
    assert @application.proofs.residency.where(submission_method: :email).exists?
  end

  test 'defaults to income when proof type is not specified' do
    # Test with no specific proof type mentioned
    receive_inbound_email_from_mail(
      to: MatVulcan::InboundEmailConfig.inbound_email_address,
      from: @constituent.email,
      subject: 'Proof documents',
      body: 'Here is my documentation.',
      attachments: {
        'proof.pdf' => @pdf_content
      }
    )

    @application.reload
    assert @application.proofs.income.where(submission_method: :email).exists?
  end

  test 'processes multiple attachments in a single email' do
    receive_inbound_email_from_mail(
      to: MatVulcan::InboundEmailConfig.inbound_email_address,
      from: @constituent.email,
      subject: 'Income Proof Submission',
      body: 'Please find my proofs attached.',
      attachments: {
        'proof1.pdf' => @pdf_content,
        'proof2.pdf' => 'Additional proof content'
      }
    )

    @application.reload
    # Count how many income proofs with email submission method were created
    income_proof_count = @application.proofs.income.where(submission_method: :email).count
    assert_equal 2, income_proof_count, 'Expected 2 income proofs to be created from the email attachments'
  end
end
