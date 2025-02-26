class Vendor < User
  # Products represent equipment
  has_many :products, foreign_key: :user_id
  has_many :vouchers, foreign_key: :vendor_id
  has_many :voucher_transactions, foreign_key: :vendor_id
  has_many :invoices, foreign_key: :vendor_id

  has_one_attached :w9_form

  validates :status, presence: true
  validates :business_name, presence: true
  validates :business_tax_id, presence: true
  validates :w9_form, presence: true, if: -> { vendor_approved? && !new_record? }
  validates :w9_form,
    content_type: { in: "application/pdf", message: "must be a PDF" },
    size: { less_than: 10.megabytes, message: "must be less than 10MB" },
    if: -> { w9_form.attached? }
  validates :terms_accepted_at, presence: true, if: :vendor_approved?

  enum :status, { pending: 0, approved: 1, suspended: 2 }, prefix: :vendor

  scope :active, -> { where(status: :approved) }
  scope :with_pending_invoices, -> {
    joins(:voucher_transactions)
      .where(voucher_transactions: { invoice_id: nil, status: :completed })
      .distinct
  }

  def pending_transaction_total
    voucher_transactions
      .completed
      .where(invoice_id: nil)
      .sum(:amount)
  end

  def total_transactions_by_period(start_date, end_date)
    voucher_transactions
      .completed
      .where("processed_at BETWEEN ? AND ?", start_date, end_date)
      .group("DATE_TRUNC('month', processed_at)")
      .sum(:amount)
  end

  def can_process_vouchers?
    vendor_approved? && w9_form.attached?
  end

  def can_be_approved?
    business_name.present? &&
      business_tax_id.present? &&
      w9_form.attached? &&
      terms_accepted_at.present?
  end

  def process_voucher!(voucher_code, amount)
    return false unless can_process_vouchers?

    voucher = Voucher.find_by(code: voucher_code)
    return false unless voucher&.can_redeem?(amount)

    voucher.redeem!(amount, self)
  end

  def latest_transactions(limit = 10)
    voucher_transactions
      .includes(:voucher)
      .order(processed_at: :desc)
      .limit(limit)
  end

  def uninvoiced_transactions
    voucher_transactions
      .includes(:voucher)
      .completed
      .where(invoice_id: nil)
      .order(processed_at: :desc)
  end
end
