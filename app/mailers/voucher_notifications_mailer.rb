class VoucherNotificationsMailer < ApplicationMailer
  include Rails.application.routes.url_helpers

  def self.default_url_options
    Rails.application.config.action_mailer.default_url_options
  end

  def prepare_email(voucher, template_name:, subject:, extra_setup: nil)
    Rails.logger.info "Preparing #{template_name} email for Voucher ID: #{voucher.id}"
    Rails.logger.info "Delivery method: #{ActionMailer::Base.delivery_method}"

    @voucher = voucher
    @application = voucher.application
    @user = @application.user

    extra_setup.call if extra_setup

    mail_obj = mail(
      to: @user.email,
      subject: subject,
      template_path: "voucher_notifications_mailer",
      template_name: template_name
    )

    Rails.logger.info "Email body: #{mail_obj.body}"
    mail_obj
  end

  def voucher_assigned(voucher)
    prepare_email(
      voucher,
      template_name: "voucher_assigned",
      subject: "Your Voucher Has Been Assigned"
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send voucher assigned email: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  def voucher_expiring_soon(voucher)
    prepare_email(
      voucher,
      template_name: "voucher_expiring_soon",
      subject: "Your Voucher Will Expire Soon",
      extra_setup: -> {
        @days_remaining = ((voucher.issued_at + Policy.voucher_validity_period) - Time.current).to_i / 1.day
        @expiration_date = (voucher.issued_at + Policy.voucher_validity_period).strftime("%B %d, %Y")
      }
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send voucher expiring soon email: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  def voucher_expired(voucher)
    prepare_email(
      voucher,
      template_name: "voucher_expired",
      subject: "Your Voucher Has Expired"
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send voucher expired email: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end

  def voucher_redeemed(transaction)
    Rails.logger.info "Preparing voucher_redeemed email for Transaction ID: #{transaction.id}"
    Rails.logger.info "Delivery method: #{ActionMailer::Base.delivery_method}"

    @transaction = transaction
    @voucher = transaction.voucher
    @application = @voucher.application
    @user = @application.user
    @vendor = transaction.vendor

    mail_obj = mail(
      to: @user.email,
      subject: "Your Voucher Has Been Redeemed",
      template_path: "voucher_notifications_mailer",
      template_name: "voucher_redeemed"
    )

    Rails.logger.info "Email body: #{mail_obj.body}"
    mail_obj
  rescue StandardError => e
    Rails.logger.error("Failed to send voucher redeemed email: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    raise e
  end
end
