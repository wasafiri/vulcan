# frozen_string_literal: true

module VendorPortal
  # Controller for managing vendor transactions
  class TransactionsController < BaseController
    include Pagy::Backend # Include Pagy::Backend for pagination

    def index
      transactions_scope = current_user.voucher_transactions.order(created_at: :desc)

      # Apply date filters if provided
      if params[:start_date].present? && params[:end_date].present?
        start_date = begin
          Date.parse(params[:start_date])
        rescue StandardError
          nil
        end
        end_date = begin
          Date.parse(params[:end_date])
        rescue StandardError
          nil
        end

        transactions_scope = transactions_scope.where(created_at: start_date.beginning_of_day..end_date.end_of_day) if start_date && end_date
      end

      # Calculate totals for the filtered transactions (before pagination)
      @total_amount = transactions_scope.sum(:amount)
      @transaction_count = transactions_scope.count

      # Paginate the transactions
      @pagy, @transactions = pagy(transactions_scope)
    end

    def show
      @transaction = current_user.voucher_transactions.find(params[:id])
      @voucher = @transaction.voucher
      @products = @transaction.products
    end
  end
end
