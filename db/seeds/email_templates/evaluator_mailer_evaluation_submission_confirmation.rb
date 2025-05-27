# Seed File for "evaluator_mailer_evaluation_submission_confirmation"
# --------------------------------------------------
EmailTemplate.create_or_find_by!(name: 'evaluator_mailer_evaluation_submission_confirmation', format: :text) do |template|
  template.subject = 'Evaluation Submission Confirmation'
  template.description = 'Sent to the evaluator after they have submitted their evaluation.'
  template.body = <<~TEXT
    %<header_text>s

    Hi %<constituent_first_name>s,

    %<status_box_text>s

    EVALUATION SUBMISSION CONFIRMATION:
    - Application ID: %<application_id>s
    - Evaluator: %<evaluator_full_name>s
    - Submission Date: %<submission_date_formatted>s

    Thank you for your prompt submission. Your evaluation is now under review.

    If you have any questions or need further assistance, please feel free to reach out.

    %<footer_text>s
  TEXT
  template.version = 1
end
puts 'Seeded evaluator_mailer_evaluation_submission_confirmation (text)' if ENV['VERBOSE_TESTS'] || Rails.env.development?
