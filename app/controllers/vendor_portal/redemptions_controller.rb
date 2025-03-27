# frozen_string_literal: true

module VendorPortal
  class RedemptionsController < VendorPortal::BaseController
    include ActionView::Helpers::NumberHelper
    def new
      @redemption = VoucherRedemption.new
    end

    def verify
      @voucher_code = params[:voucher_code]
      @voucher = Voucher.find_by(code: @voucher_code)

      if @voucher.nil?
        flash[:alert] = 'Invalid voucher code'
        redirect_to new_vendor_redemption_path
        return
      end

      unless current_user.can_process_vouchers?
        flash[:alert] = 'Your account is not approved to process vouchers yet'
        redirect_to new_vendor_redemption_path
        return
      end

      unless @voucher.can_redeem?(Policy.voucher_minimum_redemption_amount)
        flash[:alert] = voucher_status_message(@voucher)
        redirect_to new_vendor_redemption_path
        return
      end

      @redemption = VoucherRedemption.new(
        voucher_code: @voucher_code,
        amount: nil
      )
      @min_amount = Policy.voucher_minimum_redemption_amount
      @max_amount = @voucher.remaining_value
    end

    def check_voucher
      voucher = Voucher.find_by(code: params[:code])

      if voucher&.can_redeem?(0.01)
        render json: {
          valid: true,
          remaining_value: voucher.remaining_value,
          formatted_value: number_to_currency(voucher.remaining_value)
        }
      else
        render json: {
          valid: false,
          message: voucher ? voucher_status_message(voucher) : 'Invalid voucher code'
        }
      end
    end

    def create
      voucher = Voucher.find_by(code: params[:voucher_code])
      amount = params[:amount].to_f

      if voucher.nil?
        flash[:alert] = 'Invalid voucher code'
        redirect_to new_vendor_redemption_path
        return
      end

      unless current_user.can_process_vouchers?
        flash[:alert] = 'Your account is not approved to process vouchers yet'
        redirect_to new_vendor_redemption_path
        return
      end

      unless voucher.can_redeem?(amount)
        flash[:alert] = if amount > voucher.remaining_value
                          "Amount exceeds remaining voucher balance of #{number_to_currency(voucher.remaining_value)}"
                        elsif amount < Policy.voucher_minimum_redemption_amount
                          "Amount must be at least #{number_to_currency(Policy.voucher_minimum_redemption_amount)}"
                        else
                          "Voucher cannot be redeemed (#{voucher.status})"
                        end
        redirect_to verify_vendor_redemption_path(voucher_code: voucher.code)
        return
      end

      if current_user.process_voucher!(voucher.code, amount)
        redirect_to vendor_dashboard_path,
                    notice: "Successfully processed voucher for #{number_to_currency(amount)}"
      else
        flash[:alert] = 'Failed to process voucher. Please try again.'
        redirect_to verify_vendor_redemption_path(voucher_code: voucher.code)
      end
    end

    private

    # Simple struct to handle form object
    VoucherRedemption = Struct.new(:voucher_code, :amount, keyword_init: true)

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
