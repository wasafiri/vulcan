class Vendor < User
  # Products represent equipment
  has_many :products, foreign_key: :user_id

  validates :status, presence: true

  enum :status, { pending: 0, approved: 1, suspended: 2 }

  scope :active, -> { where(status: :approved) }
end
