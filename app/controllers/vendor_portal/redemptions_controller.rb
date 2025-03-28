# frozen_string_literal: true

module VendorPortal
  # Controller for voucher redemptions
  class RedemptionsController < BaseController
    def new
      # Handle direct voucher code entry
      return unless params[:code]

      @voucher = Voucher.active.find_by(code: params[:code])
      if @voucher
        redirect_to verify_vendor_voucher_path(@voucher.code)
      else
        flash[:alert] = I18n.t('alerts.invalid_voucher_code', default: 'Invalid voucher code')
        redirect_to vendor_vouchers_path
      end
    end

    def check_voucher
      code = params[:code]

      if code.blank?
        render json: { valid: false, message: 'Please enter a voucher code' }
        return
      end

      voucher = Voucher.active.find_by(code: code)

      if voucher
        render json: {
          valid: true,
          message: 'Valid voucher found',
          redirect_url: verify_vendor_voucher_path(voucher.code)
        }
      else
        render json: {
          valid: false,
          message: 'Invalid or expired voucher code' 
        }
      end
    end

    def create
      # This action is typically handled by the VouchersController#process_redemption
      redirect_to vendor_vouchers_path
    end
  end
end
