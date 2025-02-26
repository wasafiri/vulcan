class Vendor::TransactionsController < Vendor::BaseController
  include Pagy::Backend

  def index
    scope = current_user.voucher_transactions
      .includes(:voucher)
      .order(processed_at: :desc)

    scope = apply_date_filter(scope)
    @pagy, @transactions = pagy(scope, items: 25)

    respond_to do |format|
      format.html
      format.csv do
        send_data generate_csv,
          filename: "transactions-#{Time.current.strftime("%Y%m%d")}.csv",
          type: "text/csv"
      end
    end
  end

  def report
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current

    @transactions = current_user.voucher_transactions
      .completed
      .where(processed_at: start_date.beginning_of_day..end_date.end_of_day)
      .order(processed_at: :desc)

    @total_amount = @transactions.sum(:amount)
    @transaction_count = @transactions.count
    @average_amount = @transaction_count > 0 ? @total_amount / @transaction_count : 0

    respond_to do |format|
      format.html
      format.pdf do
        render pdf: "transaction_report",
          template: "vendor/transactions/report",
          layout: "pdf",
          disposition: "attachment"
      end
    end
  end

  private

  def apply_date_filter(scope)
    case params[:period]
    when "today"
      scope.where(processed_at: Time.current.beginning_of_day..Time.current.end_of_day)
    when "week"
      scope.where(processed_at: 1.week.ago.beginning_of_day..Time.current.end_of_day)
    when "month"
      scope.where(processed_at: 1.month.ago.beginning_of_day..Time.current.end_of_day)
    when "custom"
      if params[:start_date].present? && params[:end_date].present?
        start_date = Date.parse(params[:start_date])
        end_date = Date.parse(params[:end_date])
        scope.where(processed_at: start_date.beginning_of_day..end_date.end_of_day)
      else
        scope
      end
    else
      scope
    end
  end

  def generate_csv
    require "csv"

    CSV.generate(headers: true) do |csv|
      csv << [ "Date", "Voucher Code", "Amount", "Status", "Reference" ]

      @transactions.find_each do |transaction|
        csv << [
          transaction.processed_at.strftime("%Y-%m-%d %H:%M:%S"),
          transaction.voucher.code,
          transaction.amount,
          transaction.status,
          transaction.reference_number
        ]
      end
    end
  end
end
