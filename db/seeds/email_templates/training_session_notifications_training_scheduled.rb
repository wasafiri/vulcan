# Seed File for "training_session_notifications_training_scheduled"
# (Suggest saving as db/seeds/email_templates/training_session_notifications_training_scheduled.rb)
# --------------------------------------------------
EmailTemplate.create_or_find_by!(name: 'training_session_notifications_training_scheduled', format: :text) do |template|
  template.subject = 'Training Session Scheduled'
  template.description = 'Sent to the user when their training session has been scheduled.'
  template.body = <<~TEXT
    %<header_text>s

    Hello %<constituent_full_name>s,

    TRAINING SESSION SCHEDULED
    Your training session has been scheduled with %<trainer_full_name>s.

    Training Details:
    - Date: %<scheduled_date_formatted>s
    - Time: %<scheduled_time_formatted>s
    - Trainer: %<trainer_full_name>s

    If you need to reschedule or have any questions, please contact your trainer directly:
    - Email: %<trainer_email>s
    - Phone: %<trainer_phone_formatted>s

    We look forward to helping you with your training session!
    %<footer_text>s
  TEXT
  template.version = 1
end
puts 'Seeded training_session_notifications_training_scheduled (text)'
