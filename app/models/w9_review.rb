# frozen_string_literal: true

class W9Review < ApplicationRecord
  # Associations
  belongs_to :vendor, class_name: 'User'
  belongs_to :admin, class_name: 'User'

  # Enums
  enum :status, { approved: 0, rejected: 1 }, prefix: true
  enum :rejection_reason_code, {
    address_mismatch: 0,
    tax_id_mismatch: 1,
    other: 2
  }, prefix: true

  # Validations
  validates :status, :reviewed_at, presence: true
  validates :rejection_reason, presence: true, if: :status_rejected?
  validates :rejection_reason_code, presence: true, if: :status_rejected?
  validate :admin_must_be_admin_type
  validate :vendor_must_be_vendor_type
  validate :validate_rejection_fields

  # Callbacks
  before_validation :set_reviewed_at, on: :create
  after_commit :handle_post_review_actions, on: :create

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_admin, ->(admin_id) { where(admin_id: admin_id) }
  scope :rejections, -> { where(status: :rejected) }
  scope :last_3_days, -> { where('created_at > ?', 3.days.ago) }

  private

  def set_reviewed_at
    self.reviewed_at ||= Time.current
  end

  def admin_must_be_admin_type
    errors.add(:admin, 'must be an administrator') unless admin&.type == 'Administrator'
  end

  def vendor_must_be_vendor_type
    errors.add(:vendor, 'must be a vendor') unless vendor&.type == 'Vendor'
  end

  def handle_post_review_actions
    return if status.blank?

    begin
      ActiveRecord::Base.transaction do
        if status_rejected?
          increment_rejections_if_rejected
          check_max_rejections
          update_vendor_status(:rejected)
        else
          update_vendor_status(:approved)
        end
      end

      # Send appropriate notification based on status
      if status_rejected?
        send_notification('w9_rejected')
      else
        send_notification('w9_approved')
      end
    rescue StandardError => e
      Rails.logger.error "Failed to process W9 review actions: #{e.message}\n#{e.backtrace.join("\n")}"
      raise
    end
  end

  def update_vendor_status(new_status)
    vendor.update!(w9_status: new_status)
  end

  def send_notification(action)
    if action == 'w9_rejected'
      VendorNotificationsMailer.w9_rejected(vendor, self).deliver_later
    else
      VendorNotificationsMailer.w9_approved(vendor).deliver_later
    end
  rescue StandardError => e
    Rails.logger.error "Failed to send #{action} email: #{e.message}\n#{e.backtrace.join("\n")}"
    raise
  end

  def increment_rejections_if_rejected
    vendor.with_lock do
      vendor.increment!(:w9_rejections_count)
    end
  rescue StandardError => e
    errors.add(:base, "Failed to update rejection count. Please try again. Status: #{e.message}")
    raise ActiveRecord::Rollback
  end

  def check_max_rejections
    vendor.with_lock do
      if vendor.w9_rejections_count >= 8
        Notification.create!(
          recipient: User.admins.first,
          actor: admin,
          action: 'vendor_max_w9_rejections_warning',
          notifiable: vendor
        )
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to process max rejections: #{e.message}"
    errors.add(:base, 'Failed to process rejection limits')
    raise ActiveRecord::Rollback
  end

  def validate_rejection_fields
    if status_rejected?
      errors.add(:rejection_reason, 'must be provided when rejecting a W9') if rejection_reason.blank?

      errors.add(:rejection_reason_code, 'must be selected when rejecting a W9') if rejection_reason_code.blank?
    else
      # Clear rejection fields if status is not rejected
      self.rejection_reason = nil
      self.rejection_reason_code = nil
    end
  end
end
