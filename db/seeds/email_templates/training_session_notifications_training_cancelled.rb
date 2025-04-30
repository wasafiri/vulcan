# Seed File for "training_session_notifications_training_cancelled"
# --------------------------------------------------
EmailTemplate.create_or_find_by!(name: 'training_session_notifications_training_cancelled', format: :text) do |template|
  template.subject = 'Training Session Cancelled'
  template.description = 'Sent to the user when their scheduled training session has been cancelled.'
  template.body = <<~TEXT
    %<header_text>s

    Hello %<constituent_full_name>s,

    Your training session that was scheduled for %<scheduled_date_time_formatted>s has been cancelled. We apologize for any inconvenience.

    If you have questions or would like to reschedule, please contact our support team at %<support_email>s.

    %<footer_text>s
  TEXT
  template.version = 1
end
puts 'Seeded training_session_notifications_training_cancelled (text)'
