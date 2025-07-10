# frozen_string_literal: true

module VendorPortal
  # Controller for managing vendor transactions
  class TransactionsController < BaseController
    include Pagy::Backend # Include Pagy::Backend for pagination

    def index
      transactions_scope = current_user.voucher_transactions.includes(voucher: { application: :user }).order(created_at: :desc)

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

      respond_to do |format|
        format.html
        format.csv do
          send_data generate_csv(transactions_scope),
                    filename: "vendor-transactions-#{Time.current.strftime('%Y%m%d')}.csv",
                    type: 'text/csv'
        end
      end
    end

    def show
      @transaction = current_user.voucher_transactions.find(params[:id])
      @voucher = @transaction.voucher
      @products = @transaction.products
    end

    private

    def generate_csv(transactions)
      return '' if transactions.empty?

      require 'smarter_csv'
      require 'tempfile'

      transactions_data = transactions.map { |t| transaction_to_hash(t) }

      Tempfile.create(['vendor-transactions', '.csv']) do |temp_file|
        writer = SmarterCSV::Writer.new(temp_file.path)
        writer << transactions_data
        writer.finalize
        temp_file.read
      end
    end

    def transaction_to_hash(transaction)
      {
        'Date' => transaction.processed_at.strftime('%Y-%m-%d %H:%M'),
        'Voucher Code' => transaction.voucher&.code,
        'Amount' => transaction.amount,
        'Status' => transaction.status.humanize,
        'Reference Number' => transaction.reference_number,
        'Constituent Name' => transaction.voucher&.application&.user&.full_name
      }
    end
  end
end
