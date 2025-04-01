# frozen_string_literal: true

class NotifyAdminsJob < ApplicationJob
  queue_as :default

  def perform(application)
    User.where(type: 'Administrator').find_each do |admin|
      Notification.create!(
        recipient: admin,
        actor: application.user,
        action: 'proof_needs_review',
        notifiable: application
      )
    end
  end
end
