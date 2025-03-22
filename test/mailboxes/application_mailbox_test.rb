require 'test_helper'

class ApplicationMailboxTest < ActionMailbox::TestCase
  test "routes emails to Postmark inbound address to proof submission mailbox" do
    assert_mailbox_routed(ProofSubmissionMailbox) do
      receive_inbound_email_from_mail(
        to: MatVulcan::InboundEmailConfig.inbound_email_address,
        from: "constituent@example.com",
        subject: "Test Subject",
        body: "Test Body"
      )
    end
  end
  
  test "routes proof@example.com emails to proof submission mailbox" do
    assert_mailbox_routed(ProofSubmissionMailbox) do
      receive_inbound_email_from_mail(
        to: "proof@example.com",
        from: "constituent@example.com",
        subject: "Test Subject",
        body: "Test Body"
      )
    end
  end
  
  test "routes medical-cert@mdmat.org emails to medical certification mailbox" do
    assert_mailbox_routed(MedicalCertificationMailbox) do
      receive_inbound_email_from_mail(
        to: "medical-cert@mdmat.org",
        from: "doctor@example.com",
        subject: "Medical Certification",
        body: "Test Medical Certification"
      )
    end
  end
  
  test "routes unmatched emails to default mailbox" do
    assert_mailbox_routed :default do
      receive_inbound_email_from_mail(
        to: "unknown@example.com",
        from: "sender@example.com",
        subject: "Unknown Email",
        body: "This email should go to the default mailbox"
      )
    end
  end
end
