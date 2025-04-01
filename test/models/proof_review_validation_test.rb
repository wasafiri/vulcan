# frozen_string_literal: true

require 'test_helper'

class ProofReviewValidationTest < ActiveSupport::TestCase
  test "an administrator can create a proof review" do
    admin = users(:admin)
    application = applications(:in_review)
    
    proof_review = ProofReview.new(
      application: application,
      admin: admin,
      proof_type: 'income',
      status: 'approved'
    )
    
    assert proof_review.valid?, "Proof review should be valid with administrator #{admin.type}"
  end
  
  test "non-admin user cannot create a proof review" do
    user = users(:confirmed_user)
    application = applications(:in_review)
    
    proof_review = ProofReview.new(
      application: application,
      admin: user,
      proof_type: 'income',
      status: 'approved'
    )
    
    assert_not proof_review.valid?, "Proof review should not be valid with non-admin user"
    assert_includes proof_review.errors[:admin], "must be an administrator"
  end
end
