# frozen_string_literal: true

class CheckVoucherExpirationJob < ApplicationJob
  queue_as :default

  def perform
    # Activate issued vouchers that haven't been activated yet
    Voucher.pending_activation.find_each(&:activate_if_valid!)

    # Find vouchers expiring soon (7 days)
    7.days
    expiring_soon = Voucher.where(status: :active)
                           .where(
                             "issued_at + (INTERVAL '1 month' * ?) - CURRENT_TIMESTAMP BETWEEN INTERVAL '6 days' AND INTERVAL '8 days'",
                             Policy.get('voucher_validity_period_months')
                           )

    expiring_soon.find_each do |voucher|
      # Send notification to constituent
      VoucherNotificationsMailer.voucher_expiring_soon(voucher).deliver_later

      # Create event
      voucher.events.create!(
        user: nil,
        action: 'expiration_warning_sent',
        metadata: {
          days_until_expiry: 7,
          expiration_date: voucher.expiration_date
        }
      )
    end

    # Find expired vouchers that haven't been marked as expired
    expired = Voucher.where(status: :active)
                     .where(
                       "issued_at + (INTERVAL '1 month' * ?) < CURRENT_TIMESTAMP",
                       Policy.get('voucher_validity_period_months')
                     )

    expired.find_each do |voucher|
      # Mark as expired
      voucher.update!(status: :expired)

      # Send notification
      VoucherNotificationsMailer.voucher_expired(voucher).deliver_later

      # Create event
      voucher.events.create!(
        user: nil,
        action: 'expired',
        metadata: {
          expiration_date: voucher.expiration_date,
          remaining_value: voucher.remaining_value
        }
      )
    end

    # Find vouchers expiring today
    expiring_today = Voucher.where(status: :active)
                            .where(
                              "issued_at + (INTERVAL '1 month' * ?) BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '1 day')",
                              Policy.get('voucher_validity_period_months')
                            )

    expiring_today.find_each do |voucher|
      # Send final warning
      VoucherNotificationsMailer.voucher_expiring_today(voucher).deliver_later

      # Create event
      voucher.events.create!(
        user: nil,
        action: 'final_expiration_warning_sent',
        metadata: {
          expiration_date: voucher.expiration_date,
          remaining_value: voucher.remaining_value
        }
      )
    end

    # Notify admins of expired vouchers with remaining value
    expired_with_value = Voucher.where(status: :expired)
                                .where('remaining_value > 0')
                                .where(updated_at: 1.day.ago.beginning_of_day..1.day.ago.end_of_day)

    return unless expired_with_value.any?

    User.where(type: 'Users::Administrator').find_each do |admin|
      AdminNotificationsMailer.expired_vouchers_report(
        admin,
        expired_with_value
      ).deliver_later
    end
  end
end
