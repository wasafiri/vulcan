class Voucher < ApplicationRecord
  belongs_to :application
  belongs_to :vendor, optional: true, class_name: "User"
  belongs_to :invoice, optional: true
  has_many :transactions, class_name: "VoucherTransaction", dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :initial_value, :remaining_value, presence: true,
    numericality: { greater_than_or_equal_to: 0 }
  validate :remaining_value_cannot_exceed_initial_value

  before_validation :generate_code, on: :create
  before_validation :set_initial_values, on: :create
  after_create :send_assigned_notification
  after_update :check_status_changes

  enum :status, {
    issued: 0,      # Initial state when voucher is created
    active: 1,      # When voucher is ready to be used
    redeemed: 2,    # When voucher has been fully used
    expired: 3,     # When voucher has passed its expiration date
    cancelled: 4    # When voucher has been cancelled by admin
  }, default: :issued, prefix: :voucher

  scope :available, -> { where(status: [ :issued, :active ]) }
  scope :for_vendor, ->(vendor_id) { where(vendor_id: vendor_id) }
  scope :not_invoiced, -> { where(invoice_id: nil) }
  scope :expiring_soon, -> {
    expiration_threshold = 7.days
    where(status: [ :issued, :active ])
      .where(
        "issued_at + (INTERVAL '1 month' * ?) - CURRENT_TIMESTAMP <= INTERVAL '? days'",
        Policy.get("voucher_validity_period_months"),
        expiration_threshold.to_i
      )
  }

  def expired?
    return true if status == "expired"
    if issued_at
      issued_at + Policy.voucher_validity_period <= Time.current
    else
      false
    end
  end

  def expiration_date
    issued_at + Policy.voucher_validity_period if issued_at
  end

  def days_until_expiration
    return nil unless issued_at
    ((issued_at + Policy.voucher_validity_period) - Time.current).to_i / 1.day
  end

  def can_redeem?(amount)
    return false unless voucher_active?
    return false if expired?
    return false if amount > remaining_value
    return false if amount < Policy.voucher_minimum_redemption_amount
    true
  end

  def redeem!(amount, vendor)
    return false unless can_redeem?(amount)

    transaction do
      # Create transaction record
      txn = transactions.create!(
        vendor: vendor,
        amount: amount,
        transaction_type: :redemption,
        status: :transaction_completed,
        processed_at: Time.current,
        reference_number: generate_reference_number
      )

      # Update remaining value and vendor
      self.remaining_value -= amount
      self.last_used_at = Time.current
      self.vendor = vendor

      # Update status if fully redeemed
      self.status = :redeemed if remaining_value.zero?

      save!

      # Send notification
      VoucherNotificationsMailer.voucher_redeemed(txn).deliver_later

      txn
    end
  end

  def cancel!
    return false unless can_cancel?

    update!(
      status: :cancelled,
      notes: [ notes, "Cancelled at #{Time.current}" ].compact.join("\n")
    )
  end

  def can_cancel?
    voucher_issued? || voucher_active?
  end

  def initial_value=(value)
    super(value.try(:round, 2))
  end

  def remaining_value=(value)
    super(value.try(:round, 2))
  end

  private

  def send_assigned_notification
    VoucherNotificationsMailer.voucher_assigned(self).deliver_later
  end

  def check_status_changes
    if saved_change_to_status?
      case status
      when "expired"
        VoucherNotificationsMailer.voucher_expired(self).deliver_later
      end
    end
  end

  def remaining_value_cannot_exceed_initial_value
    if remaining_value && initial_value && remaining_value > initial_value
      errors.add(:remaining_value, "cannot exceed initial value")
    end
  end

  def generate_code
    return if code.present?
    loop do
      self.code = SecureRandom.alphanumeric(12).upcase
      break unless Voucher.exists?(code: code)
    end
  end

  def generate_reference_number
    "TXN-#{SecureRandom.hex(6).upcase}"
  end

  def self.calculate_value_for_constituent(constituent)
    Constituent::DISABILITY_TYPES.sum do |disability_type|
      # Explicitly check for true to handle any truthy/falsey values
      if constituent.send("#{disability_type}_disability") == true
        Policy.voucher_value_for_disability(disability_type)
      else
        0
      end
    end
  end

  def set_initial_values
    return if initial_value.present? && remaining_value.present?

    if application&.user
      total_value = self.class.calculate_value_for_constituent(application.user)
      self.initial_value = total_value
      self.remaining_value = total_value
      self.issued_at = Time.current
    else
      self.initial_value = 0
      self.remaining_value = 0
      self.issued_at = Time.current
    end
  end
end
