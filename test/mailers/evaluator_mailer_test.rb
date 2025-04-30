# frozen_string_literal: true

require 'test_helper'

class EvaluatorMailerTest < ActionMailer::TestCase
  # Helper to create mock templates
  def mock_template(subject, body)
    template = mock('email_template')
    template.stubs(:render).returns([subject, body])
    template
  end

  setup do
    # Mock EmailTemplate lookups
    html_mock = mock_template('Mock Subject', '<p>Mock HTML Body</p>')
    text_mock = mock_template('Mock Subject', 'Mock Text Body')
    EmailTemplate.stubs(:find_by!)
                 .with(has_entry(format: :html))
                 .returns(html_mock)
    EmailTemplate.stubs(:find_by!)
                 .with(has_entry(format: :text))
                 .returns(text_mock)

    # Create test data using FactoryBot
    @evaluation = create(:evaluation)
    @evaluator = @evaluation.evaluator
    @constituent = @evaluation.constituent
    @application = @evaluation.application
  end

  test 'new_evaluation_assigned' do
    email = EvaluatorMailer.with(evaluation: @evaluation).new_evaluation_assigned

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@evaluator.email], email.to
    assert_match 'New Evaluation', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'assigned'
    assert_includes html_part.body.to_s, @constituent.full_name

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'assigned'
    assert_includes text_part.body.to_s, @constituent.full_name
  end

  test 'evaluation_submission_confirmation' do
    # Use .with() to pass parameters
    email = EvaluatorMailer.with(evaluation: @evaluation).evaluation_submission_confirmation

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@constituent.email], email.to
    assert_match 'Evaluation has been Submitted', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'completed'
    assert_includes html_part.body.to_s, @evaluator.full_name

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'completed'
    assert_includes text_part.body.to_s, @evaluator.full_name
  end

  test 'evaluation_submission_confirmation generates letter when preference is letter' do
    # Set constituent communication preference to 'letter'
    @constituent.update!(communication_preference: 'letter')

    # Expect TextTemplateToPdfService to be called
    Letters::TextTemplateToPdfService.any_instance.expects(:queue_for_printing).once

    # Call the mailer method
    email = EvaluatorMailer.with(evaluation: @evaluation).evaluation_submission_confirmation

    # Deliver the email to trigger the service call
    assert_emails 1 do
      email.deliver_later
    end

    # Basic email assertions can still be included if desired
    assert_match 'Evaluation has been Submitted', email.subject
  end
end
