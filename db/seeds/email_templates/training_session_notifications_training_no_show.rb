# Seed File for "training_session_notifications_training_no_show"
# (Suggest saving as db/seeds/email_templates/training_session_notifications_training_no_show.rb)
# --------------------------------------------------
EmailTemplate.create_or_find_by!(name: 'training_session_notifications_training_no_show', format: :text) do |template|
  template.subject = 'Training Session No Show'
  template.description = 'Sent to the user when they have not shown up for their scheduled training session.'
  template.body = <<~TEXT
    %<header_text>s

    Hello %<constituent_full_name>s,

    We noticed you did not attend your training session scheduled for %<scheduled_date_time_formatted>s. If you need to reschedule, please contact your trainer at %<trainer_email>s or our support team at %<support_email>s.

    Thank you,
    %<footer_text>s
  TEXT
  template.version = 1
end
puts 'Seeded training_session_notifications_training_no_show (text)' if ENV['VERBOSE_TESTS'] || Rails.env.development?
