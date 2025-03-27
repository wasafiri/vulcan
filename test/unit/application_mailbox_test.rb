# frozen_string_literal: true

require 'test_helper'

class ApplicationMailboxRoutingTest < ActionMailbox::TestCase
  test 'routes proof@example.com emails to proof submission mailbox' do
    inbound_email = create_inbound_email_from_mail(
      from: 'sender@example.com',
      to: 'proof@example.com',
      subject: 'Test Subject'
    )

    assert_equal 'ProofSubmissionMailbox', inbound_email.mailbox_name
  end

  test 'routes emails to Postmark inbound address to proof submission mailbox' do
    # Save original values
    original_address = MatVulcan::InboundEmailConfig.inbound_email_address

    # Set test address
    MatVulcan::InboundEmailConfig.inbound_email_address = 'test-hash@inbound.postmarkapp.com'

    inbound_email = create_inbound_email_from_mail(
      from: 'sender@example.com',
      to: 'test-hash@inbound.postmarkapp.com',
      subject: 'Test Subject'
    )

    assert_equal 'ProofSubmissionMailbox', inbound_email.mailbox_name

    # Restore original address
    MatVulcan::InboundEmailConfig.inbound_email_address = original_address
  end

  test 'routes medical-cert@mdmat.org emails to medical certification mailbox' do
    inbound_email = create_inbound_email_from_mail(
      from: 'sender@example.com',
      to: 'medical-cert@mdmat.org',
      subject: 'Test Subject'
    )

    assert_equal 'MedicalCertificationMailbox', inbound_email.mailbox_name
  end

  test 'routes unmatched emails to default mailbox' do
    inbound_email = create_inbound_email_from_mail(
      from: 'sender@example.com',
      to: 'random@example.com',
      subject: 'Test Subject'
    )

    assert_equal ApplicationMailbox.default_mailbox_name, inbound_email.mailbox_name
  end
end
