# frozen_string_literal: true

# Handles all operations related to voucher management
# This includes voucher assignment, creation, and eligibility checks
module VoucherManagement
  extend ActiveSupport::Concern

  # Assigns a new voucher to this application
  # @param assigned_by [User] The user assigning the voucher (defaults to Current.user)
  # @return [Voucher, false] The created voucher or false on failure
  def assign_voucher!(assigned_by: nil)
    return false unless can_create_voucher?

    with_lock do
      voucher = vouchers.create!
      Event.create!(
        user: assigned_by || Current.user,
        action: 'voucher_assigned',
        metadata: {
          application_id: id,
          voucher_id: voucher.id,
          voucher_code: voucher.code,
          initial_value: voucher.initial_value,
          timestamp: Time.current.iso8601
        }
      )

      # Notify constituent
      create_system_notification!(
        recipient: user,
        actor: assigned_by || Current.user,
        action: 'voucher_assigned'
      )

      voucher
    end
  rescue StandardError => e
    Rails.logger.error "Failed to assign voucher for application #{id}: #{e.message}"
    false
  end

  # Checks if this application is eligible to receive a voucher
  # @return [Boolean] True if the application can receive a voucher
  def can_create_voucher?
    status_approved? &&
      medical_certification_status_approved? &&
      !vouchers.exists?
  end

  # Creates an initial voucher for a newly approved application
  # @return [Voucher, nil] The created voucher or nil if not eligible
  def create_initial_voucher
    return unless can_create_voucher?

    assign_voucher!(assigned_by: Current.user)
  end

  private

  def create_system_notification!(recipient:, actor:, action:)
    Notification.create!(
      recipient: recipient,
      actor: actor,
      action: action,
      notifiable: self,
      metadata: {
        application_id: id,
        timestamp: Time.current.iso8601
      }
    )
  end
end
