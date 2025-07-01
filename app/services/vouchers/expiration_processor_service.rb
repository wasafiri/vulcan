# frozen_string_literal: true

module Vouchers
  # Service to process voucher expiration logic
  class ExpirationProcessorService < BaseService
    def call
      # Activate issued vouchers that haven't been activated yet
      Voucher.pending_activation.find_each(&:activate_if_valid!)

      process_expiring_soon_vouchers
      process_expired_vouchers
      process_expiring_today_vouchers
      notify_admins_of_expired_vouchers

      success('Voucher expiration processing completed')
    rescue StandardError => e
      log_error(e, 'Failed to process voucher expirations')
      failure('Failed to process voucher expirations')
    end

    private

    def process_expiring_soon_vouchers
      vouchers_expiring_soon.find_each do |voucher|
        VoucherNotificationsMailer.voucher_expiring_soon(voucher).deliver_later
        voucher.events.create!(
          user: nil,
          action: 'expiration_warning_sent',
          metadata: { days_until_expiry: 7, expiration_date: voucher.expiration_date }
        )
      end
    end

    def process_expired_vouchers
      expired_vouchers.find_each do |voucher|
        voucher.update!(status: :expired)
        VoucherNotificationsMailer.voucher_expired(voucher).deliver_later
        voucher.events.create!(
          user: nil,
          action: 'expired',
          metadata: { expiration_date: voucher.expiration_date, remaining_value: voucher.remaining_value }
        )
      end
    end

    def process_expiring_today_vouchers
      vouchers_expiring_today.find_each do |voucher|
        VoucherNotificationsMailer.voucher_expiring_today(voucher).deliver_later
        voucher.events.create!(
          user: nil,
          action: 'final_expiration_warning_sent',
          metadata: { expiration_date: voucher.expiration_date, remaining_value: voucher.remaining_value }
        )
      end
    end

    def notify_admins_of_expired_vouchers
      expired_with_value = Voucher.where(status: :expired)
                                  .where('remaining_value > 0')
                                  .where(updated_at: 1.day.ago.all_day)
      return unless expired_with_value.any?

      User.where(type: 'Users::Administrator').find_each do |admin|
        AdminNotificationsMailer.expired_vouchers_report(admin, expired_with_value).deliver_later
      end
    end

    def vouchers_expiring_soon
      @vouchers_expiring_soon ||= active_vouchers.where(
        "issued_at + (INTERVAL '1 month' * ?) - CURRENT_TIMESTAMP BETWEEN INTERVAL '6 days' AND INTERVAL '8 days'",
        voucher_validity_period
      )
    end

    def expired_vouchers
      @expired_vouchers ||= active_vouchers.where(
        "issued_at + (INTERVAL '1 month' * ?) < CURRENT_TIMESTAMP",
        voucher_validity_period
      )
    end

    def vouchers_expiring_today
      @vouchers_expiring_today ||= active_vouchers.where(
        "issued_at + (INTERVAL '1 month' * ?) BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '1 day')",
        voucher_validity_period
      )
    end

    def active_vouchers
      @active_vouchers ||= Voucher.where(status: :active)
    end

    def voucher_validity_period
      @voucher_validity_period ||= Policy.get('voucher_validity_period_months')
    end
  end
end
