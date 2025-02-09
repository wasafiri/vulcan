class ProofReviewReminderJob < ApplicationJob
  queue_as :default

  def perform
    # Find applications needing review for 3+ days
    stale_applications = Application.stale_reviews

    return if stale_applications.empty?

    # Group applications by assigned admin if applicable
    # For now, send to all admins
    User.where(type: "Admin").find_each do |admin|
      ApplicationNotificationsMailer.proof_needs_review_reminder(admin, stale_applications)
        .deliver_now
    end
  end
end
