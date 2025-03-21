class Invoice < ApplicationRecord
  belongs_to :vendor, class_name: "User"
  has_many :vouchers, dependent: :nullify
  has_many :voucher_transactions, dependent: :nullify

  validates :vendor, presence: true
  validates :start_date, :end_date, presence: true
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :invoice_number, presence: true, uniqueness: true
  validate :end_date_after_start_date
  validate :dates_do_not_overlap_for_vendor

  before_validation :generate_invoice_number, on: :create
  before_validation :calculate_total_amount, on: :create

  enum :status, {
    invoice_draft: 0,        # Initial state when invoice is created
    invoice_pending: 1,      # Ready for review and processing
    invoice_approved: 2,     # Approved for payment
    invoice_paid: 3,         # Payment has been processed
    invoice_cancelled: 4     # Invoice has been cancelled
  }, prefix: true

  scope :unpaid, -> { where.not(status: %i[invoice_paid invoice_cancelled]) }
  scope :for_vendor, ->(vendor_id) { where(vendor_id: vendor_id) }
  scope :in_date_range, ->(start_date, end_date) {
    where("start_date >= ? AND end_date <= ?", start_date, end_date)
  }
  scope :needs_processing, -> { where(status: :invoice_pending) }

  def self.generate_biweekly
    # Find vendors with uninvoiced transactions
    vendor_ids = VoucherTransaction.pending_invoice
                                   .select(:vendor_id)
                                   .distinct
                                   .pluck(:vendor_id)

    vendor_ids.each do |vendor_id|
      # Calculate date range for this invoice
      latest_invoice = for_vendor(vendor_id).order(end_date: :desc).first
      start_date = latest_invoice ? latest_invoice.end_date : 14.days.ago.beginning_of_day
      end_date = Time.current.end_of_day

      # Create invoice
      create_for_vendor(vendor_id, start_date, end_date)
    end
  end

  def self.create_for_vendor(vendor_id, start_date, end_date)
    # Get all completed, uninvoiced transactions for this vendor in date range
    transactions = VoucherTransaction
                   .completed
                   .pending_invoice
                   .for_vendor(vendor_id)
                   .in_date_range(start_date, end_date)

    return if transactions.empty?

    transaction do
      # Create invoice
      invoice = create!(
        vendor_id: vendor_id,
        start_date: start_date,
        end_date: end_date,
        status: :invoice_pending
      )

      # Associate transactions and vouchers with this invoice
      transactions.each do |txn|
        txn.update!(invoice: invoice)
        txn.voucher.update!(invoice: invoice) if txn.voucher.invoice_id.nil?
      end

      invoice
    end
  end

  validates :gad_invoice_reference, presence: true, if: :invoice_paid?

  before_save :set_timestamps
  after_save :send_payment_notification, if: :payment_details_added?

  private

  def set_timestamps
    if status_changed? && invoice_approved?
      self.approved_at = Time.current
    end

    if status_changed? && invoice_paid? && gad_invoice_reference.present?
      self.payment_recorded_at = Time.current
    end
  end

  def payment_details_added?
    saved_change_to_status? && invoice_paid? && gad_invoice_reference.present?
  end

  def send_payment_notification
    VendorNotificationsMailer.payment_issued(self).deliver_later

    # Update associated records
    voucher_transactions.update_all(status: VoucherTransaction.statuses[:transaction_completed])
    vouchers.where(status: :voucher_active).update_all(status: :voucher_redeemed)
  end

  def total_transaction_amount
    voucher_transactions.sum(:amount)
  end

  def generate_invoice_number
    return if invoice_number.present?

    date_part = Time.current.strftime("%Y%m")
    sequence = (self.class.where("invoice_number LIKE ?", "INV-#{date_part}-%")
      .count + 1).to_s.rjust(4, "0")

    self.invoice_number = "INV-#{date_part}-#{sequence}"
  end

  def calculate_total_amount
    self.total_amount = total_transaction_amount
  end

  def end_date_after_start_date
    return unless start_date && end_date

    if end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def dates_do_not_overlap_for_vendor
    return unless start_date && end_date && vendor_id

    overlapping = self.class
      .where(vendor_id: vendor_id)  # Only check same vendor
      .where.not(id: id)            # Exclude self when updating
      .where("start_date <= ? AND end_date >= ?", end_date, start_date)
      .exists?

    if overlapping
      errors.add(:base, "Date range overlaps with an existing invoice")
    end
  end
end
