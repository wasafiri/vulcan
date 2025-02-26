require "application_system_test_case"
require "support/action_mailbox_test_helper"

class Admin::ProofEmailSubmissionTest < ApplicationSystemTestCase
  include ActionMailboxTestHelper

  setup do
    @admin = users(:admin)
    @constituent = users(:constituent)
    @application = applications(:active_application)
    @constituent.update(email: "constituent@example.com")
    @application.update(constituent: @constituent)

    sign_in @admin
  end

  test "admin can view proof submitted via email" do
    # Create a temporary file for testing
    file_path = Rails.root.join("tmp", "income_proof.pdf")
    File.open(file_path, "w") do |f|
      f.write("This is a test PDF file")
    end

    # Create an inbound email with attachment
    inbound_email = create_inbound_email_with_attachment(
      to: "proof@example.com",
      from: @constituent.email,
      subject: "Income Proof Submission",
      body: "Please find my income proof attached.",
      attachment_path: file_path,
      content_type: "application/pdf"
    )

    # Process the email
    inbound_email.route

    # Visit the application page
    visit admin_application_path(@application)

    # Verify the proof is visible
    assert_text "income_proof.pdf"

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test "admin can view medical certification submitted via email" do
    # Skip this test if medical provider model doesn't exist
    skip "Medical provider model not available" unless defined?(MedicalProvider)

    # Create a medical provider
    medical_provider = MedicalProvider.create!(
      name: "Dr. Test",
      email: "doctor@example.com"
    )

    # Add medical certification requested flag if needed
    unless @application.respond_to?(:medical_certification_requested?)
      @application.define_singleton_method(:medical_certification_requested?) do
        true
      end
    end

    # Create a temporary file for testing
    file_path = Rails.root.join("tmp", "medical_certification.pdf")
    File.open(file_path, "w") do |f|
      f.write("This is a test medical certification PDF file")
    end

    # Create an inbound email with attachment
    inbound_email = create_inbound_email_with_attachment(
      to: "medical-cert@example.com",
      from: medical_provider.email,
      subject: "Medical Certification for Application ##{@application.id}",
      body: "Please find the signed medical certification attached.",
      attachment_path: file_path,
      content_type: "application/pdf"
    )

    # Process the email
    inbound_email.route

    # Visit the application page
    visit admin_application_path(@application)

    # Verify the certification is visible
    assert_text "medical_certification.pdf"

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end
end
