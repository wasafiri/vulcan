# frozen_string_literal: true

# Tests for ApplicationMailbox routing
#
# This test suite verifies that emails are correctly routed to the appropriate mailboxes
# based on their recipient addresses.
#
# Key dependencies:
# - MatVulcan::InboundEmailConfig - Defined in config/initializers/01_inbound_email_config.rb
# - MailboxTestHelper - Defined in test/support/mailbox_test_helper.rb
# - ApplicationMailbox - Defined in app/mailboxes/application_mailbox.rb
# - ProofSubmissionMailbox - Defined in app/mailboxes/proof_submission_mailbox.rb
# - MedicalCertificationMailbox - Defined in app/mailboxes/medical_certification_mailbox.rb

require 'test_helper'

class ApplicationMailboxTest < ActionMailbox::TestCase
  include MailboxTestHelper

  setup do
    # Create users needed for mailbox processing with FactoryBot
    @constituent = create(:constituent, email: 'constituent@example.com')
    @medical_provider = create(:medical_provider, email: 'doctor@example.com')

    # Create an active application for the constituent to avoid bounce
    @application = create(:application, user: @constituent, status: :in_progress)
    @application.update_columns(
      income_proof_status: :not_reviewed,
      residency_proof_status: :not_reviewed
    )

    # Mock ProofAttachmentValidator to prevent validation failures
    ProofAttachmentValidator.stubs(:validate!).returns(true)

    # Mock the bounce_with_notification to prevent actual bounces
    ProofSubmissionMailbox.any_instance.stubs(:bounce_with_notification).returns(nil)

    # Stub attach_proof to prevent actual attachment processing
    ProofSubmissionMailbox.any_instance.stubs(:attach_proof).returns(true)

    # Add rate limit and policy stubs
    RateLimit.stubs(:check!).returns(true)
    Policy.stubs(:get).with('proof_submission_rate_period').returns(1)
    Policy.stubs(:get).with('proof_submission_rate_limit_email').returns(100)
    Policy.stubs(:get).with('max_proof_rejections').returns(100)

    # Clear deliveries before each test
    ActionMailer::Base.deliveries.clear
  end

  test 'routes emails to Postmark inbound address to proof submission mailbox' do
    email = receive_inbound_email_from_mail(
      to: MatVulcan::InboundEmailConfig.inbound_email_address,
      from: @constituent.email, # Use created user's email
      subject: 'Test Subject',
      body: 'Test Body'
    )
    assert_mailbox_routed email, to: 'proof_submission'
  end

  test 'routes proof@example.com emails to proof submission mailbox' do
    email = receive_inbound_email_from_mail(
      to: 'proof@example.com',
      from: @constituent.email, # Use created user's email
      subject: 'Test Subject',
      body: 'Test Body'
    )
    assert_mailbox_routed email, to: 'proof_submission'
  end

  test 'routes medical-cert@mdmat.org emails to medical certification mailbox' do
    # Need to stub Event creation to avoid FK violation when routing to MedicalCertificationMailbox
    # This is just testing the routing logic, not the full mailbox functionality
    Event.stubs(:create!).returns(true)

    # Also stub bounce_with_notification to prevent actual bounce
    MedicalCertificationMailbox.any_instance.stubs(:bounce_with_notification).returns(nil)
    # Stub additional methods to prevent 'constituent' method errors
    MedicalCertificationMailbox.any_instance.stubs(:create_audit_record).returns(true)
    MedicalCertificationMailbox.any_instance.stubs(:process).returns(true)
    MedicalCertificationMailbox.any_instance.stubs(:constituent).returns(@constituent)

    email = receive_inbound_email_from_mail(
      to: 'medical-cert@mdmat.org',
      from: @medical_provider.email, # Use created user's email
      subject: 'Medical Certification',
      body: 'Test Medical Certification'
    )
    assert_mailbox_routed email, to: 'medical_certification'
  end

  test 'routes unmatched emails to default mailbox' do
    email = receive_inbound_email_from_mail(
      to: 'unknown@example.com',
      from: 'sender@example.com',
      subject: 'Unknown Email',
      body: 'This email should go to the default mailbox'
    )
    assert_mailbox_routed email, to: :default
  end
end
