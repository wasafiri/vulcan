# frozen_string_literal: true

module VendorPortal
  # Controller for managing vendor transactions
  class TransactionsController < BaseController
    def index
      @transactions = current_user.voucher_transactions.order(created_at: :desc)

      # Apply date filters if provided
      if params[:start_date].present? && params[:end_date].present?
        start_date = Date.parse(params[:start_date]) rescue nil
        end_date = Date.parse(params[:end_date]) rescue nil

        if start_date && end_date
          @transactions = @transactions.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
        end
      end

      # Calculate totals for the filtered transactions
      @total_amount = @transactions.sum(:amount)
      @transaction_count = @transactions.count
    end

    def show
      @transaction = current_user.voucher_transactions.find(params[:id])
      @voucher = @transaction.voucher
      @products = @transaction.products
    end
  end
end
