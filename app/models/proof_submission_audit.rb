# frozen_string_literal: true

class ProofSubmissionAudit < ApplicationRecord
  belongs_to :application
  belongs_to :user

  # Define the enum for submission_method to match SubmissionMethodValidator.VALID_METHODS
  enum :submission_method, {
    web: 0,
    paper: 1,
    email: 2,
    unknown: 3
  }, prefix: :submission_method

  validates :proof_type, presence: true
  validates :ip_address, presence: true
  validates :submission_method, presence: true

  # Generate a human-readable description of the proof submission event
  def description
    "#{proof_type.to_s.humanize} proof submitted via #{submission_method}"
  end

  # Disable suspicious activity notification in test environment
  after_create :notify_admins_if_suspicious, unless: -> { Rails.env.test? }

  private

  def notify_admins_if_suspicious
    return unless suspicious?

    # Only run in production to avoid test failures
    return unless Rails.env.production?

    # Use Rails logger if AdminNotifier is not available
    if defined?(AdminNotifier)
      AdminNotifier.new(
        subject: 'Suspicious Proof Submission',
        message: "Multiple submissions detected from IP #{ip_address}",
        level: :warning
      ).notify_all
    else
      Rails.logger.warn "Suspicious proof submission detected from IP #{ip_address}"
    end
  end

  def suspicious?
    recent_submissions_from_ip > 10
  end

  def recent_submissions_from_ip
    self.class
        .where(ip_address: ip_address)
        .where('created_at > ?', 1.hour.ago)
        .count
  end
end
