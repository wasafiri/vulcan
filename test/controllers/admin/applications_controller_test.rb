require "test_helper"

class Admin::ApplicationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_david)
    @application = create(:application, :in_progress_with_approved_proofs)

    # Use the fixed sign_in helper with headers
    @headers = {
      "HTTP_USER_AGENT" => "Rails Testing",
      "REMOTE_ADDR" => "127.0.0.1"
    }

    post sign_in_path,
      params: { email: @admin.email, password: "password123" },
      headers: @headers

    assert_response :redirect
    follow_redirect!
  end

  def test_index_displays_applications
    # Create applications and use them in assertions
    completed = create(:application, :completed)
    in_progress = create(:application, :in_progress_with_rejected_proofs)

    get admin_applications_path
    assert_response :success
    assert_select "table.applications-table" do
      assert_select ".application-row", count: 3 # Two created + one from setup
      assert_application_row(completed)
      assert_application_row(in_progress)
    end
  end

  def test_index_filters_applications_needing_proof_review
    needs_review = create(:application, :in_progress_with_rejected_proofs)

    get admin_applications_path, params: { filter: "proofs_needing_review" }
    assert_response :success
    assert_select ".application-row", { text: /#{needs_review.user.last_name}/ }
  end

  def test_approves_income_proof_with_notification
    application = create(:application, :in_progress)

    assert_difference -> { application.proof_reviews.count } do
      post update_proof_status_admin_application_path(application), params: {
        proof_type: "income",
        status: "approved"
      }
    end

    application.reload
    assert application.income_proof_status_approved?
    assert_equal "Income proof approved successfully.", flash[:notice]
  end

  def test_rejects_proof_with_constituent_notification
    application = create(:application, :in_progress)

    assert_difference [ "application.proof_reviews.count", "Notification.count" ] do
      post update_proof_status_admin_application_path(application), params: {
        proof_type: "income",
        status: "rejected",
        rejection_reason: "Document unclear"
      }
    end

    application.reload
    assert application.income_proof_status_rejected?
    assert_equal "Income proof rejected successfully.", flash[:notice]
  end

  def test_batch_approves_eligible_applications
    app1 = create(:application, :in_progress_with_approved_proofs)
    app2 = create(:application, :in_progress_with_approved_proofs)

    post batch_approve_admin_applications_path, params: {
      ids: [ app1.id, app2.id ]
    }

    assert_redirected_to admin_applications_path
    assert_equal "Applications approved.", flash[:notice]
    assert app1.reload.approved?
    assert app2.reload.approved?
  end

  def test_handles_invalid_batch_approval
    invalid_app = create(:application, :in_progress_with_rejected_proofs)

    post batch_approve_admin_applications_path, params: {
      ids: [ invalid_app.id ]
    }

    assert_response :unprocessable_entity
    assert_not invalid_app.reload.approved?
  end

  def test_requests_additional_documents
    assert_difference -> { Notification.count } do
      post request_documents_admin_application_path(@application)
    end

    @application.reload
    assert @application.awaiting_documents?
    assert_equal "Documents requested.", flash[:notice]
  end

  def test_searches_applications_by_constituent_name
    # Use the created application instead of creating a new one
    get search_admin_applications_path, params: { q: @application.user.last_name }
    assert_response :success
    assert_application_row(@application)
  end

  def test_show_page_loads_with_application_notes_form
    get admin_application_path(@application)
    assert_response :success

    # Verify the application notes form is present
    assert_select "form[action=?]", admin_application_notes_path(@application)
    assert_select "textarea[name='application_note[content]']"
    assert_select "input[name='application_note[internal_only]']"
    assert_select "input[type=submit][value='Add Note']"
  end
  
  def test_resend_medical_certification
    # Setup application with medical provider email
    @application.update(medical_provider_email: "provider@example.com")
    
    assert_enqueued_with(job: MedicalCertificationEmailJob) do
      post resend_medical_certification_admin_application_path(@application)
    end

    @application.reload
    assert_equal "requested", @application.medical_certification_status
    assert_equal 1, @application.medical_certification_request_count
    assert_redirected_to admin_application_path(@application)
    assert_equal "Certification request sent successfully.", flash[:notice]
  end

  def test_resend_medical_certification_creates_notification
    # Setup application with medical provider email
    @application.update(medical_provider_email: "provider@example.com")
    
    assert_difference 'Notification.count' do
      post resend_medical_certification_admin_application_path(@application)
    end

    notification = Notification.last
    assert_equal "medical_certification_requested", notification.action
    assert_equal @application.user, notification.recipient
    assert_equal @admin, notification.actor
    
    # Check that metadata contains the timestamp and request count
    assert notification.metadata.present?
    assert notification.metadata.key?("timestamp")
    assert_equal 1, notification.metadata["request_count"]
  end

  def test_resend_medical_certification_without_provider_email
    # Setup application without medical provider email
    @application.update(medical_provider_email: nil)
    
    post resend_medical_certification_admin_application_path(@application)
    
    assert_redirected_to admin_application_path(@application)
    assert_match /Failed to process certification request/, flash[:alert]
    
    # Verify the job was not enqueued
    assert_no_enqueued_jobs only: MedicalCertificationEmailJob
  end

  def test_resend_medical_certification_increments_count
    # Setup application with existing request count
    @application.update(
      medical_provider_email: "provider@example.com",
      medical_certification_status: "requested",
      medical_certification_request_count: 1
    )
    
    post resend_medical_certification_admin_application_path(@application)
    
    @application.reload
    assert_equal 2, @application.medical_certification_request_count
    
    # Check notification has the correct count
    notification = Notification.last
    assert_equal 2, notification.metadata["request_count"]
  end

  def teardown
    Current.reset
  end
end
