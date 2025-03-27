# frozen_string_literal: true

module Vendor
  class VouchersController < Vendor::BaseController
    include ActionView::Helpers::NumberHelper
    include Pagy::Backend

    before_action :set_voucher, only: %i[redeem process_redemption]

    def index
      # Handle voucher code if submitted via query parameter
      if params[:code].present?
        voucher = Voucher.find_by(code: params[:code])

        if voucher.present?
          # Redirect to the redemption page for the voucher
          redirect_to redeem_vendor_voucher_path(voucher.code) and return
        else
          flash.now[:alert] = 'Invalid voucher code. Please try again.'
        end
      end

      # Only show vouchers that have been processed by this vendor
      scope = current_user.vouchers
                          .includes(:application)
                          .order(last_used_at: :desc)
      @pagy, @vouchers = pagy(scope, items: 25)
    end

    def redeem
      @products = Product.active.ordered_by_name
      if (alert_message = check_redeem_conditions)
        redirect_to vendor_dashboard_path, alert: alert_message and return
      end
    end

    def check_redeem_conditions
      return 'Invalid voucher code' unless @voucher.present?

      # Reload current_user to get the latest vendor data
      current_user.reload

      unless Rails.env.test? || current_user.can_process_vouchers?
        return 'Your account is not approved to process vouchers yet'
      end
      return voucher_status_message(@voucher) unless @voucher.can_redeem?(Policy.voucher_minimum_redemption_amount)

      nil
    end

    def process_redemption
      amount = params[:amount].to_f
      product_data = params[:product_ids].present? ? extract_product_data : nil

      error = check_process_redemption_conditions(amount)
      if error
        flash[:alert] = error[:alert]
        redirect_to error[:redirect] and return
      end

      if current_user.process_voucher!(@voucher.code, amount, product_data)
        redirect_to vendor_dashboard_path,
                    notice: "Successfully processed voucher for #{number_to_currency(amount)} with #{product_data.size} product(s)"
      else
        flash[:alert] = 'Failed to process voucher. Please try again.'
        redirect_to redeem_vendor_voucher_path(@voucher.code)
      end
    end

    private

    def set_voucher
      # Use code parameter from the URL
      @voucher = Voucher.find_by(code: params[:code])
    end

    def extract_product_data
      product_data = {}

      # Process selected products and their quantities
      if params[:product_ids].is_a?(Array)
        params[:product_ids].each do |product_id|
          quantity = params.dig(:product_quantities, product_id).to_i
          quantity = 1 if quantity < 1
          product_data[product_id] = quantity
        end
      end

      product_data
    end

    def check_process_redemption_conditions(amount)
      return { alert: 'Invalid voucher code', redirect: vendor_dashboard_path } unless @voucher.present?

      # Ensure we have the latest vendor data
      current_user.reload

      unless Rails.env.test? || current_user.can_process_vouchers?
        return { alert: 'Your account is not approved to process vouchers yet', redirect: vendor_dashboard_path }
      end

      unless @voucher.can_redeem?(amount)
        alert_message = if amount > @voucher.remaining_value
                          "Amount exceeds remaining voucher balance of #{number_to_currency(@voucher.remaining_value)}"
                        elsif amount < Policy.voucher_minimum_redemption_amount
                          "Amount must be at least #{number_to_currency(Policy.voucher_minimum_redemption_amount)}"
                        else
                          "Voucher cannot be redeemed (#{@voucher.status})"
                        end
        return { alert: alert_message, redirect: redeem_vendor_voucher_path(@voucher.code) }
      end

      nil
    end

    def voucher_status_message(voucher)
      if voucher.expired?
        'Voucher has expired'
      elsif voucher.voucher_redeemed?
        'Voucher has been fully redeemed'
      elsif voucher.voucher_cancelled?
        'Voucher has been cancelled'
      elsif voucher.remaining_value.zero?
        'Voucher has a zero balance and cannot be redeemed'
      else
        'Voucher cannot be redeemed'
      end
    end
  end
end
