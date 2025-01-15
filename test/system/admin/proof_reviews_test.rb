# test/system/admin/proof_reviews_test.rb
require "test_helper"

class Admin::ProofReviewsTest < ApplicationSystemTestCase
  test "approving all proofs triggers medical provider contact" do
    admin = create(:admin)
    application = create(:application, :in_review)

    sign_in admin
    visit admin_application_path(application)

    click_on "Review Income Proof"
    choose "Approve"
    click_on "Submit & Exit"

    assert_text "Medical provider has been contacted"
    assert_equal "awaiting_documents", application.reload.status
  end
end
