# Represents a voucher that can be redeemed by constituents for assistive technology products
class Voucher < ApplicationRecord
  belongs_to :application
  belongs_to :vendor, optional: true, class_name: 'User'
  belongs_to :invoice, optional: true
  has_many :transactions, class_name: 'VoucherTransaction', dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :initial_value, :remaining_value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :remaining_value_cannot_exceed_initial_value

  before_validation :generate_code, on: :create
  before_validation :set_initial_values, on: :create
  after_create :send_assigned_notification
  after_update :check_status_changes
  after_update :log_status_change, if: -> { saved_change_to_status? && respond_to?(:events) }

  enum :status, {
    active: 0,      # Initial state when voucher is created and ready to be used
    redeemed: 2,    # When voucher has been fully used
    expired: 3,     # When voucher has passed its expiration date
    cancelled: 4    # When voucher has been cancelled by admin
  }, default: :active, prefix: :voucher

  scope :available, -> { where(status: :active) }
  scope :for_vendor, ->(vendor_id) { where(vendor_id: vendor_id) }
  scope :not_invoiced, -> { where(invoice_id: nil) }
  scope :expiring_soon, lambda {
    expiration_threshold = 7.days
    where(status: :active)
      .where(
        "issued_at + (INTERVAL '1 month' * ?) - CURRENT_TIMESTAMP <= ? * INTERVAL '1 day'",
        Policy.get('voucher_validity_period_months'),
        expiration_threshold.to_i
      )
  }

  def expired?
    return true if status == 'expired'

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

  def activate_if_valid!
    # Don't modify if voucher is already in a final state
    return if %w[redeemed cancelled].include?(status)

    # If voucher is already active, only check if it needs to be marked as expired
    if status == 'active'
      update!(status: :expired) if expired?
      return
    end

    # For any other status, check if it should be expired or active
    if expired?
      update!(status: :expired)
    else
      update!(status: :active)
    end
  end

  def can_redeem?(amount)
    return false unless voucher_active?
    return false if expired?
    return false if amount > remaining_value
    return false if amount < Policy.voucher_minimum_redemption_amount

    true
  end

  def redeem!(amount, vendor, product_data = nil)
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

      # Associate products with the transaction
      if product_data.present?
        product_data.each do |product_id, quantity|
          product = Product.find(product_id)
          txn.voucher_transaction_products.create!(
            product: product,
            quantity: quantity.to_i
          )

          # Associate products with the application
          application.products << product unless application.products.include?(product)
        end
      end

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
      notes: [notes, "Cancelled at #{Time.current}"].compact.join("\n")
    )
  end

  def can_cancel?
    voucher_active?
  end

  def initial_value=(value)
    super(value.try(:round, 2))
  end

  def remaining_value=(value)
    super(value.try(:round, 2))
  end

  # Override to_param to return the voucher code
  def to_param
    code
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

  private

  def send_assigned_notification
    VoucherNotificationsMailer.voucher_assigned(self).deliver_later
  end

  def check_status_changes
    return unless saved_change_to_status?

    case status
    when 'expired'
      VoucherNotificationsMailer.voucher_expired(self).deliver_later
    end
  end

  def log_status_change
    events.create!(
      user: nil,
      action: "status_changed_to_#{status}",
      metadata: {
        previous_status: status_before_last_save,
        current_status: status,
        timestamp: Time.current
      }
    )
  end

  def remaining_value_cannot_exceed_initial_value
    if remaining_value && initial_value && remaining_value > initial_value
      errors.add(:remaining_value, 'cannot exceed initial value')
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
