# frozen_string_literal: true

class VoucherTransactionProduct < ApplicationRecord
  belongs_to :voucher_transaction
  belongs_to :product

  validates :quantity, presence: true, numericality: { greater_than: 0, only_integer: true }
end
