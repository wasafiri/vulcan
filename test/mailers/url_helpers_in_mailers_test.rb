require "test_helper"

class UrlHelpersInMailersTest < ActionMailer::TestCase
  fixtures :all

  setup do
    # Set up application and related objects
    @application = applications(:one)
    @user = @application.user
    @proof_review = proof_reviews(:income_approved)

    # Set up evaluation and related objects
    @evaluation = evaluations(:one)
    @evaluator = @evaluation.evaluator
    @constituent = @evaluation.constituent

    # Set up vendor using FactoryBot
    @vendor = FactoryBot.create(:vendor)

    # Configure default URL options for testing
    Rails.application.config.action_mailer.default_url_options = { host: "test.example.com" }
  end

  test "proof_rejected email contains absolute URLs" do
    email = ApplicationNotificationsMailer.proof_rejected(@application, @proof_review)

    # Test both HTML and text parts
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }

    # Check for absolute URLs in HTML part
    assert_match(/href="http:\/\/test\.example\.com/, html_part.body.to_s)

    # Check for absolute URLs in text part
    assert_match(/http:\/\/test\.example\.com/, text_part.body.to_s)
  end

  test "new_evaluation_assigned email contains absolute URLs" do
    email = EvaluatorMailer.with(evaluation: @evaluation).new_evaluation_assigned

    # Test both HTML and text parts
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }

    # Check for absolute URLs in HTML part
    assert_match(/href="http:\/\/test\.example\.com/, html_part.body.to_s)

    # Check for absolute URLs in text part
    assert_match(/http:\/\/test\.example\.com/, text_part.body.to_s)
  end

  # Skip vendor-related tests for now as they require additional setup
  # that's beyond the scope of this URL helper test
end
