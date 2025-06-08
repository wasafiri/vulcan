# frozen_string_literal: true

require 'test_helper'

# This test is a copy of the controller test, using the integration test approach
class ProofSubmissionFlowTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @user = create(:constituent, email: 'johnny-test@example.com')
    @application = create(:application, user: @user, status: :needs_information, income_proof_status: :rejected, residency_proof_status: :rejected)
    @valid_pdf = fixture_file_upload('test/fixtures/files/placeholder_income_proof.pdf', 'application/pdf')

    # Use the sign_in helper from test_helper.rb
    sign_in(@user)
  end

  test 'submits proof successfully when proof is rejected' do
    # Set up application with rejected income proof
    @application.update!(income_proof_status: 'rejected')

    assert_changes '@application.reload.income_proof_status',
                   from: 'rejected',
                   to: 'not_reviewed' do
      assert_changes '@application.reload.needs_review_since',
                     from: nil do
        assert_difference 'Event.count', 2 do # ProofAttachmentService creates one, tracking creates another
          # Use the direct path
          post "/constituent_portal/applications/#{@application.id}/proofs/resubmit",
               params: { proof_type: 'income', income_proof: @valid_pdf }

          # Verify response and flash
          assert_response :redirect
          follow_redirect!
          assert_equal 'Proof submitted successfully', flash[:notice]

          # Verify application updates
          @application.reload
          assert @application.income_proof.attached?, 'Income proof should be attached'
          assert_equal 'not_reviewed', @application.income_proof_status
          assert_not_nil @application.needs_review_since

          # Verify audit trail and events
          assert_audit_and_events
        end
      end
    end
  end

  test 'cannot submit proof if not rejected' do
    # Set application to not_reviewed status (not rejected)
    @application.update!(income_proof_status: 'not_reviewed')

    assert_no_changes '@application.reload.income_proof_status' do
      assert_no_difference 'Event.count' do
        # Use the direct path
        post "/constituent_portal/applications/#{@application.id}/proofs/resubmit",
             params: { proof_type: 'income', income_proof: @valid_pdf }

        # Verify response and flash
        assert_response :redirect
        follow_redirect!
        assert_equal 'Invalid proof type or status', flash[:alert]

        # Check no proof was attached
        assert_not @application.reload.income_proof.attached?, 'Income proof should not be attached'
      end
    end
  end

  def assert_audit_and_events
    # Verify events were created (one from ProofAttachmentService, one from tracking)
    events = Event.where(action: 'proof_submitted').order(created_at: :desc).limit(2)
    assert_equal 2, events.count, 'Expected 2 proof_submitted events'

    # Check the most recent event (from tracking)
    tracking_event = events.first
    assert_equal 'proof_submitted', tracking_event.action
    assert_equal @user, tracking_event.user
    assert_equal @application.id.to_s, tracking_event.metadata['application_id']
    assert_equal 'income', tracking_event.metadata['proof_type']
    assert_equal 'web', tracking_event.metadata['submission_method']

    # Check the attachment event (from ProofAttachmentService)
    attachment_event = events.second
    assert_equal 'proof_submitted', attachment_event.action
    assert_equal @user, attachment_event.user
    assert_equal @application, attachment_event.auditable
    assert_equal 'income', attachment_event.metadata['proof_type']
  end

  test 'requires authentication' do
    path = "/constituent_portal/applications/#{@application.id}/proofs/resubmit"

    # Ensure application is in a state where proof can be submitted and no proof is initially attached
    @application.update!(income_proof_status: 'rejected')
    @application.income_proof.detach if @application.income_proof.attached?
    @application.reload
    assert_not @application.income_proof.attached?, 'Setup: Income proof should not be attached initially'

    # A. Authenticated POST: Should succeed and attach the proof.
    post path, params: { proof_type: 'income', income_proof: @valid_pdf }
    assert_response :redirect
    @application.reload
    assert @application.income_proof.attached?, 'Proof should be attached after authenticated post'

    # B. Detach proof to reset state for unauthenticated check
    @application.income_proof.detach
    @application.save!
    @application.reload
    assert_not @application.income_proof.attached?, 'Proof should be detached before unauthenticated post attempt'

    # C. Sign out
    sign_out
    assert cookies[:session_token].blank?, "Session token cookie should be blank after sign_out, was: '#{cookies[:session_token]}'"

    # D. Unauthenticated POST: Should redirect unauthenticated user to sign_in and NOT attach any proof.
    post path, params: { proof_type: 'income', income_proof: @valid_pdf }

    # Get redirect details to debug
    puts "DEBUG REDIRECT TO: #{response.redirect_url}"
    puts "DEBUG SIGN_IN_PATH: #{sign_in_path}"

    # Check for redirect to sign in
    assert_equal sign_in_path, URI(response.redirect_url).path

    # Verify no changes occurred
    @application.reload
    assert_not @application.income_proof.attached?, 'Income proof should not be attached when not authenticated'
  end
end
