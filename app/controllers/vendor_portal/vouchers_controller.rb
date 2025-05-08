# frozen_string_literal: true

module VendorPortal
  # Controller for managing vouchers
  class VouchersController < BaseController
    before_action :set_voucher, only: %i[verify verify_dob redeem process_redemption]
    before_action :check_voucher_active, only: %i[verify redeem]
    before_action :check_identity_verified, only: %i[redeem]

    def index
      @vouchers = current_user.processed_vouchers.order(updated_at: :desc)

      return if params[:code].blank?

      voucher = Voucher.where(status: :active).find_by(code: params[:code])
      if voucher
        redirect_to verify_vendor_voucher_path(voucher.code)
      else
        flash.now[:alert] = t('alerts.invalid_voucher_code', default: 'Invalid voucher code')
      end
    end

    def verify
      # Initialize the verification attempts
      reset_verification_attempts
    end

    def verify_dob
      # Use the verification service to check the DOB
      verification_service = VoucherVerificationService.new(
        @voucher,
        params[:date_of_birth],
        session
      )

      result = verification_service.verify

      # Record verification attempt in events
      record_verification_event(result.success?)

      if result.success?
        flash[:notice] = t(result.message_key)
        redirect_to redeem_vendor_voucher_path(@voucher.code)
      else
        flash[:alert] = if result.attempts_left&.positive?
                          t(result.message_key, attempts_left: result.attempts_left)
                        else
                          t(result.message_key)
                        end

        if result.attempts_left&.zero?
          redirect_to vendor_vouchers_path
        else
          redirect_to verify_vendor_voucher_path(@voucher.code)
        end
      end
    end

    def redeem
      # check_voucher_active and check_identity_verified before actions
      # will redirect if necessary
      @products = Product.order(:name)
    end

    def process_redemption
      # Validate the vendor can process vouchers
      unless current_user.vendor_approved?
        flash[:alert] = 'Your account is not approved for processing vouchers yet'
        redirect_to redeem_vendor_voucher_path(@voucher.code)
        return
      end

      # Validate the voucher can be redeemed using the correct enum helper
      unless @voucher.voucher_active? # Use the prefixed helper method
        flash[:alert] = 'This voucher is not active or has already been processed'
        redirect_to vendor_vouchers_path
        return
      end

      # Validate identity has been verified
      unless identity_verified?(@voucher)
        flash[:alert] = 'Identity verification is required before redemption'
        redirect_to verify_vendor_voucher_path(@voucher.code)
        return
      end

      # Validate the redemption amount
      redemption_amount = params[:amount].to_f
      available_amount = @voucher.remaining_value

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
        notes: params[:notes],
        transaction_type: 'redemption',
        status: 'transaction_completed'
      )

      # Associate products if provided
      if params[:product_ids].present?
        params[:product_ids].each do |product_id|
          quantity = params[:product_quantities][product_id.to_s].to_i
          quantity = 1 if quantity < 1 # ensure at least quantity of 1
          transaction.voucher_transaction_products.build(
            product_id: product_id,
            quantity: quantity
          )
        end
      end

      # Also associate products with the application
      if params[:product_ids].present?
        application = @voucher.application
        params[:product_ids].each do |product_id|
          application.products << Product.find(product_id) unless application.products.include?(Product.find(product_id))
        rescue StandardError => e
          Rails.logger.error("Failed to associate product: #{e.message}")
        end
      end

      if transaction.save
        # Reload the voucher to ensure we have the latest data
        @voucher.reload

        # Update voucher remaining value - use direct SQL update to avoid race conditions
        new_remaining_value = @voucher.remaining_value - redemption_amount
        new_status = new_remaining_value.zero? || new_remaining_value.abs < 0.01 ? 'redeemed' : 'active'

        Voucher.where(id: @voucher.id).update_all(
          remaining_value: new_remaining_value,
          vendor_id: current_user.id,
          status: new_status
        )

        # Reload to get updated values
        @voucher.reload

        flash[:notice] = 'Voucher successfully processed'
        redirect_to vendor_dashboard_path
      else
        flash[:alert] = "Error processing voucher: #{transaction.errors.full_messages.join(', ')}"
        redirect_to redeem_vendor_voucher_path(@voucher.code)
      end
    end

    private

    def set_voucher
      # Use params[:code] as defined in the routes, not params[:id]
      @voucher = Voucher.find_by!(code: params[:code])
    end

    def check_voucher_active
      return if @voucher.voucher_active?

      flash[:alert] = 'This voucher is not active or has already been processed'
      redirect_to vendor_vouchers_path
    end

    def check_identity_verified
      return if identity_verified?(@voucher)

      flash[:alert] = 'Identity verification is required before redemption'
      redirect_to verify_vendor_voucher_path(@voucher.code)
    end

    def identity_verified?(voucher)
      session[:verified_vouchers].present? &&
        session[:verified_vouchers].include?(voucher.id)
    end

    def reset_verification_attempts
      session[:voucher_verification_attempts] ||= {}
      session[:voucher_verification_attempts][@voucher.id.to_s] = 0
    end

    def record_verification_event(successful)
      Event.create!(
        user: current_user,
        action: 'voucher_verification_attempt',
        metadata: {
          voucher_id: @voucher.id,
          voucher_code: @voucher.code,
          constituent_id: @voucher.application.user_id,
          successful: successful,
          attempt_number: session[:voucher_verification_attempts][@voucher.id.to_s] || 0
        }
      )
    end
  end
end
