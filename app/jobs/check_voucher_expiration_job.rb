# frozen_string_literal: true

class CheckVoucherExpirationJob < ApplicationJob
  queue_as :default

  def perform
    result = Vouchers::ExpirationProcessorService.new.call

    return if result.success?

    Rails.logger.error "CheckVoucherExpirationJob failed: #{result.message}"
    raise StandardError, result.message
  end
end
