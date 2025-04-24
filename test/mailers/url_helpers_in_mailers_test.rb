# frozen_string_literal: true

require 'test_helper'

class UrlHelpersInMailersTest < ActionMailer::TestCase
  setup do
    # Set up application and related objects using factories instead of fixtures
    @user = create(:constituent)
    @application = create(:application, user: @user)

    # Create a proof review with approved status for the application
    @proof_review = create(:proof_review,
                           application: @application,
                           proof_type: 'income',
                           status: :approved,
                           admin: create(:admin))

    # Set up evaluation and related objects
    @evaluator = create(:evaluator)
    @constituent = create(:constituent)
    # Let the factory handle products implicitly, don't try to set product directly
    @evaluation = create(:evaluation,
                         evaluator: @evaluator,
                         constituent: @constituent,
                         status: :requested)

    # Set up vendor
    @vendor = create(:vendor)

    # Configure default URL options for testing
    Rails.application.config.action_mailer.default_url_options = { host: 'test.example.com' }
  end

  test 'proof_rejected email contains absolute URLs' do
    email = ApplicationNotificationsMailer.proof_rejected(@application, @proof_review)

    # Test both HTML and text parts
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }

    # Check for absolute URLs in HTML part
    assert_match(%r{href="http://test\.example\.com}, html_part.body.to_s)

    # Check for absolute URLs in text part
    assert_match(%r{http://test\.example\.com}, text_part.body.to_s)
  end

  test 'new_evaluation_assigned email contains absolute URLs' do
    email = EvaluatorMailer.with(evaluation: @evaluation).new_evaluation_assigned

    # Test both HTML and text parts
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }

    # Check for absolute URLs in HTML part
    assert_match(%r{href="http://test\.example\.com}, html_part.body.to_s)

    # Check for absolute URLs in text part
    assert_match(%r{http://test\.example\.com}, text_part.body.to_s)
  end

  # Skip vendor-related tests for now as they require additional setup
  # that's beyond the scope of this URL helper test
end
