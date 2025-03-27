# frozen_string_literal: true

module VendorPortal
  # Controller for managing vouchers
  class VouchersController < BaseController
    before_action :set_voucher, only: [:redeem, :process_redemption]

    def index
      @vouchers = current_user.processed_vouchers.order(updated_at: :desc)

      # Handle voucher code lookups from URL params
      if params[:code].present?
        voucher = Voucher.active.find_by(code: params[:code])
        if voucher
          redirect_to redeem_vendor_voucher_path(voucher.code)
        else
          flash.now[:alert] = 'Invalid voucher code'
        end
      end
    end

    def redeem
      unless @voucher.active?
        flash[:alert] = 'This voucher is not active or has already been processed'
        redirect_to vendor_vouchers_path
      end
    end

    def process_redemption
      # Validate the vendor can process vouchers
      unless current_user.vendor_approved?
        flash[:alert] = 'Your account is not approved for processing vouchers yet'
        redirect_to redeem_vendor_voucher_path(@voucher.code)
        return
      end

      # Validate the voucher can be redeemed
      unless @voucher.active?
        flash[:alert] = 'This voucher is not active or has already been processed'
        redirect_to vendor_vouchers_path
        return
      end

      # Validate the redemption amount
      redemption_amount = params[:amount].to_f
      available_amount = @voucher.amount - @voucher.redeemed_amount

      if redemption_amount <= 0
        flash[:alert] = 'Redemption amount must be greater than zero'
        redirect_to redeem_vendor_voucher_path(@voucher.code)
        return
      end

      if redemption_amount > available_amount
        flash[:alert] = "Cannot redeem more than the available amount (#{number_to_currency(available_amount)})"
        redirect_to redeem_vendor_voucher_path(@voucher.code)
        return
      end

      # Create transaction
      transaction = VoucherTransaction.new(
        voucher: @voucher,
        vendor: current_user,
        amount: redemption_amount,
        notes: params[:notes]
      )

      # Associate products if provided
      if params[:product_ids].present?
        params[:product_ids].each do |product_id|
          transaction.voucher_transaction_products.build(product_id: product_id)
        end
      end

      if transaction.save
        # Update voucher redeemed amount
        @voucher.update(
          redeemed_amount: @voucher.redeemed_amount + redemption_amount,
          status: (@voucher.redeemed_amount + redemption_amount >= @voucher.amount) ? :completed : :active
        )

        flash[:notice] = 'Voucher successfully processed'
        redirect_to vendor_dashboard_path
      else
        flash[:alert] = "Error processing voucher: #{transaction.errors.full_messages.join(', ')}"
        redirect_to redeem_vendor_voucher_path(@voucher.code)
      end
    end

    private

    def set_voucher
      @voucher = Voucher.find_by!(code: params[:id])
    end
  end
end
