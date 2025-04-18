# frozen_string_literal: true

require 'test_helper'

class ApplicationMailboxTest < ActionMailbox::TestCase
  setup do
    # Create users needed for mailbox processing
    @constituent = create(:constituent, email: 'constituent@example.com')
    @medical_provider = create(:medical_provider, email: 'doctor@example.com')
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
