# frozen_string_literal: true

class GuardianRelationship < ApplicationRecord
  belongs_to :guardian_user, class_name: 'User', foreign_key: 'guardian_id', inverse_of: :guardian_relationships_as_guardian
  belongs_to :dependent_user, class_name: 'User', foreign_key: 'dependent_id', inverse_of: :guardian_relationships_as_dependent

  validates :guardian_id, presence: true
  validates :dependent_id, presence: true
  validates :relationship_type, presence: true

  validates :dependent_id, uniqueness: { scope: :guardian_id, message: 'relationship already exists for this guardian and dependent' }
end
