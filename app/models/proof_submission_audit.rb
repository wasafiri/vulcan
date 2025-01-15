# app/models/proof_submission_audit.rb
class ProofSubmissionAudit < ApplicationRecord
  belongs_to :application
  belongs_to :user

  validates :proof_type, presence: true
  validates :ip_address, presence: true

  after_create :notify_admins_if_suspicious

  private

  def notify_admins_if_suspicious
    return unless suspicious?

    AdminNotifier.new(
      subject: "Suspicious Proof Submission",
      message: "Multiple submissions detected from IP #{ip_address}",
      level: :warning
    ).notify_all
  end

  def suspicious?
    recent_submissions_from_ip > 10
  end

  def recent_submissions_from_ip
    self.class
      .where(ip_address: ip_address)
      .where("created_at > ?", 1.hour.ago)
      .count
  end
end
