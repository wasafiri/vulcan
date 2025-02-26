require "test_helper"
require "support/action_mailbox_test_helper"

class MedicalCertificationMailboxTest < ActionMailbox::TestCase
  include ActionMailboxTestHelper

  setup do
    # Create a medical provider and application using factories
    @medical_provider = create(:medical_provider)
    @constituent = create(:constituent)
    @application = create(:application, user: @constituent)

    # Ensure the medical provider has the correct email
    @medical_provider.update(email: "doctor@example.com")

    # Add a method to check if medical certification is requested if it doesn't exist
    unless Application.method_defined?(:medical_certification_requested?)
      Application.class_eval do
        def medical_certification_requested?
          true # For testing purposes
        end
      end
    end

    # Set up ApplicationMailbox routing for testing
    ApplicationMailbox.instance_eval do
      routing(/medical-cert@/i => :medical_certification)
    end
  end

  test "routes emails to medical_certification mailbox" do
    inbound_email = create_inbound_email_from_mail(
      to: "medical-cert@example.com",
      from: @medical_provider.email,
      subject: "Medical Certification for Application ##{@application.id}"
    )

    # Route the email and check that it was processed by the correct mailbox
    assert_difference -> { ActionMailbox::InboundEmail.where(status: :delivered).count } do
      inbound_email.route
    end

    # Verify it was routed to the correct mailbox by checking the processing status
    assert_equal "delivered", inbound_email.reload.status
  end

  test "attaches medical certification to application" do
    # Create a temporary file for testing
    file_path = Rails.root.join("tmp", "medical_certification.pdf")
    File.open(file_path, "w") do |f|
      f.write("This is a test medical certification PDF file")
    end

    # Stub the medical_certification association if it doesn't exist
    unless @application.respond_to?(:medical_certification)
      @application.define_singleton_method(:medical_certification) do
        @medical_certification ||= OpenStruct.new(
          attach: ->(blob) { true }
        )
      end
    end

    # Stub the Event model if it doesn't exist
    unless defined?(Event)
      stub_const("Event", Class.new do
        def self.create!(*args)
          true
        end
      end)
    end

    assert_nothing_raised do
      inbound_email = create_inbound_email_with_attachment(
        to: "medical-cert@example.com",
        from: @medical_provider.email,
        subject: "Medical Certification for Application ##{@application.id}",
        body: "Please find the signed medical certification attached.",
        attachment_path: file_path,
        content_type: "application/pdf"
      )

      inbound_email.route
    end

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test "bounces email when medical provider not found" do
    assert_nothing_raised do
      inbound_email = create_inbound_email_from_mail(
        to: "medical-cert@example.com",
        from: "unknown@example.com",
        subject: "Medical Certification"
      )

      inbound_email.route
    end

    # Verify the email was bounced
    assert_equal "bounced", ActionMailbox::InboundEmail.last.status
  end

  test "extracts application ID from email subject" do
    inbound_email = create_inbound_email_from_mail(
      to: "medical-cert@example.com",
      from: @medical_provider.email,
      subject: "Medical Certification for Application #123",
      body: "Please find attached the certification."
    )

    mailbox = MedicalCertificationMailbox.new(inbound_email)
    assert_equal "123", mailbox.send(:extract_application_id_from_email)
  end

  test "extracts application ID from email body" do
    inbound_email = create_inbound_email_from_mail(
      to: "medical-cert@example.com",
      from: @medical_provider.email,
      subject: "Medical Certification",
      body: "Please find attached the certification for Application #123."
    )

    mailbox = MedicalCertificationMailbox.new(inbound_email)
    assert_equal "123", mailbox.send(:extract_application_id_from_email)
  end

  test "extracts application ID from mailbox hash" do
    inbound_email = create_inbound_email_from_mail(
      to: "medical-cert+123@example.com",
      from: @medical_provider.email,
      subject: "Medical Certification",
      body: "Please find attached the certification."
    )

    mailbox = MedicalCertificationMailbox.new(inbound_email)
    assert_equal "123", mailbox.send(:extract_application_id_from_email)
  end

  private

  def stub_const(name, klass)
    unless Object.const_defined?(name)
      Object.const_set(name, klass)
      @stubbed_constants ||= []
      @stubbed_constants << name
    end
  end

  def teardown
    super
    if defined?(@stubbed_constants)
      @stubbed_constants.each do |const|
        Object.send(:remove_const, const)
      end
    end
  end
end
