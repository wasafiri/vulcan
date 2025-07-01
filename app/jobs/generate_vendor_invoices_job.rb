# frozen_string_literal: true

# Job to generate invoices for vendors with uninvoiced transactions
#
# LOGIC FLOW:
# 1. This job delegates ALL business logic to Invoices::GenerationService
# 2. The service handles:
#    - Finding vendors with uninvoiced transactions
#    - Calculating date ranges for each vendor
#    - Creating invoices with proper associations
#    - Sending notifications to vendors and admins
#    - Logging all operations
#
# DEPENDENCIES:
# - Invoices::GenerationService (app/services/invoices/generation_service.rb)
# - VoucherTransaction model (for finding uninvoiced transactions)
# - Invoice model (for creating invoices)
# - VendorNotificationsMailer (for vendor notifications)
# - AdminNotificationsMailer (for admin notifications)
#
# TRIGGERED BY:
# - Scheduled job (likely via recurring gem or cron)
# - Manual execution from admin interface
#
class GenerateVendorInvoicesJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info 'Starting GenerateVendorInvoicesJob'

    # Delegate all business logic to the service
    # See: app/services/invoices/generation_service.rb
    result = Invoices::GenerationService.new.call

    if result.failure?
      Rails.logger.error "GenerateVendorInvoicesJob failed: #{result.message}"
      raise StandardError, result.message
    end

    Rails.logger.info "GenerateVendorInvoicesJob completed: #{result.message}"
  end
end
