# frozen_string_literal: true

require 'test_helper'

class ApplicationMailboxTest < ActionMailbox::TestCase
  test 'routes emails to Postmark inbound address to proof submission mailbox' do
    assert_routing MatVulcan::InboundEmailConfig.inbound_email_address => 'proof_submission'
  end

  test 'routes proof@example.com emails to proof submission mailbox' do
    assert_routing 'proof@example.com' => 'proof_submission'
  end

  test 'routes medical-cert@mdmat.org emails to medical certification mailbox' do
    assert_routing 'medical-cert@mdmat.org' => 'medical_certification'
  end

  test 'routes unmatched emails to default mailbox' do
    assert_routing 'unknown@example.com' => 'application'
  end
end
