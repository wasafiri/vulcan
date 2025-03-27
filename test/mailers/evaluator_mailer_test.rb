# frozen_string_literal: true

require 'test_helper'

class EvaluatorMailerTest < ActionMailer::TestCase
  setup do
    @evaluation = evaluations(:one)
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
    email = EvaluatorMailer.evaluation_submission_confirmation(@evaluation)

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
end
