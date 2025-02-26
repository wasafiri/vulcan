class CheckVoucherExpirationJob < ApplicationJob
  queue_as :default

  def perform
    # Find vouchers expiring soon (7 days)
    expiring_soon = Voucher.active
      .where(expiration_date: 7.days.from_now.beginning_of_day..7.days.from_now.end_of_day)

    expiring_soon.find_each do |voucher|
      # Send notification to constituent
      VoucherNotificationsMailer.voucher_expiring_soon(voucher).deliver_later

      # Create event
      voucher.events.create!(
        user: nil,
        action: "expiration_warning_sent",
        metadata: {
          days_until_expiry: 7,
          expiration_date: voucher.expiration_date
        }
      )
    end

    # Find expired vouchers that haven't been marked as expired
    expired = Voucher.active
      .where("expiration_date < ?", Time.current)

    expired.find_each do |voucher|
      # Mark as expired
      voucher.update!(status: :expired)

      # Send notification
      VoucherNotificationsMailer.voucher_expired(voucher).deliver_later

      # Create event
      voucher.events.create!(
        user: nil,
        action: "expired",
        metadata: {
          expiration_date: voucher.expiration_date,
          remaining_value: voucher.remaining_value
        }
      )
    end

    # Find vouchers expiring today
    expiring_today = Voucher.active
      .where(expiration_date: Time.current.beginning_of_day..Time.current.end_of_day)

    expiring_today.find_each do |voucher|
      # Send final warning
      VoucherNotificationsMailer.voucher_expiring_today(voucher).deliver_later

      # Create event
      voucher.events.create!(
        user: nil,
        action: "final_expiration_warning_sent",
        metadata: {
          expiration_date: voucher.expiration_date,
          remaining_value: voucher.remaining_value
        }
      )
    end

    # Notify admins of expired vouchers with remaining value
    expired_with_value = Voucher.expired
      .where("remaining_value > 0")
      .where(expiration_date: 1.day.ago.beginning_of_day..1.day.ago.end_of_day)

    if expired_with_value.any?
      Admin.find_each do |admin|
        AdminNotificationsMailer.expired_vouchers_report(
          admin,
          expired_with_value
        ).deliver_later
      end
    end
  end
end
