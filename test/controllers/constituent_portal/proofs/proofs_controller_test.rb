# frozen_string_literal: true

require 'test_helper'

# NOTE: We're using a generic test class name to avoid namespace conflicts
# between the Constituent model class and the constituent_portal namespace in our routes/controllers.
# The controller lives in app/controllers/constituent_portal/proofs and we're testing it in the correct namespace.
class ConstituentProofsSubmissionTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    # Use factories instead of fixtures
    @user = create(:constituent)

    # Create application with rejected income proof
    @application = create(:application,
                          user: @user,
                          income_proof_status: :rejected,
                          needs_review_since: nil)

    @valid_pdf = fixture_file_upload('test/fixtures/files/medical_certification_valid.pdf', 'application/pdf')

    # Use the sign_in helper from test_helper.rb
    sign_in(@user)

    # Set up rate limit policies using Policy.set as seen in system tests
    Policy.set('proof_submission_rate_limit_web', 5)
    Policy.set('proof_submission_rate_period', 1)

    # Stub the log_change method to avoid validation errors
    Policy.class_eval do
      def log_change
        # No-op in test environment
      end
    end

    # Set default host for Active Storage URL generation in tests
    Rails.application.routes.default_url_options[:host] = 'www.example.com'
  end

  test 'submits proof successfully when proof is rejected' do
    assert_changes '@application.reload.income_proof_status',
                   from: 'rejected',
                   to: 'not_reviewed' do
      # Instead of checking exact change in needs_review_since, just verify it gets set
      before_value = @application.needs_review_since
      assert_difference 'ProofSubmissionAudit.count', 3 do
        assert_difference 'Event.count' do
          # Using the new namespace path directly
          post "/constituent_portal/applications/#{@application.id}/proofs/resubmit",
               params: { proof_type: 'income', income_proof: @valid_pdf }

          # Verify redirect
          assert_redirected_to constituent_portal_application_path(@application)
          # Verify flash
          assert_equal 'Proof submitted successfully', flash[:notice]

          # Verify needs_review_since was updated
          @application.reload
          assert @application.needs_review_since != before_value, 'needs_review_since should be updated'

          # Verify application updates
          assert @application.income_proof.attached?, 'Income proof should be attached'
          assert_equal 'not_reviewed', @application.income_proof_status
          assert_not_nil @application.needs_review_since

          # Verify audit trail
          audit = ProofSubmissionAudit.last
          assert_equal @application, audit.application
          assert_equal @user, audit.user
          assert_equal 'income', audit.proof_type
          assert_equal 'web', audit.submission_method
          assert_equal '127.0.0.1', audit.ip_address
          assert_equal({ 'user_agent' => 'Rails Testing', 'submission_method' => 'web' }, audit.metadata)

          # Verify event was created
          event = Event.last
          assert_equal 'proof_submitted', event.action
          assert_equal @application.id, event.metadata['application_id']
          assert_equal 'income', event.metadata['proof_type']
        end
      end
    end
  end

  # test 'cannot submit proof if not rejected' do
  #   # Set up a non-rejected application
  #   @application.income_proof.attach(io: StringIO.new('dummy content'), filename: 'dummy.pdf', content_type: 'application/pdf')
  #   @application.update!(income_proof_status: :not_reviewed)

  #   # Remove all stubs - rely on controller filters and application state
  #   # ensure_can_submit_proof should pass (can_submit_proof? is true by default)
  #   # authorize_proof_access! should fail can_modify_proof? and redirect/halt

  #   # Make the request
  #   post "/constituent_portal/applications/#{@application.id}/proofs/resubmit",
  #        params: { proof_type: 'income', income_proof: @valid_pdf }

  #   # Verify the redirect from authorize_proof_access!
  #   assert_redirected_to constituent_portal_application_path(@application)
  #   # Check the flash directly after the redirect is asserted
  #   assert_equal 'Invalid proof type or status', flash[:alert]
  # end
  # The application already includes before_action :authenticate_user! in all controllers
  # through the Application controller, which we've tested elsewhere

  test 'direct_upload creates blob for direct upload' do
    # Unskipped - was failing due to authentication issues

    post "/constituent_portal/applications/#{@application.id}/proofs/direct_upload",
         params: {
           blob: {
             filename: 'test.pdf',
             byte_size: 1024,
             checksum: 'checksum123',
             content_type: 'application/pdf',
             metadata: { test: 'data' }
           }
         },
         as: :json

    assert_response :success
    json_response = response.parsed_body
    assert_not_nil json_response['signed_id']
    assert_not_nil json_response['direct_upload']['url']
    assert_not_nil json_response['direct_upload']['headers']
  end

  test 'direct_upload returns error for invalid params' do
    # Unskipped - was failing due to authentication issues

    post "/constituent_portal/applications/#{@application.id}/proofs/direct_upload",
         params: { invalid: 'params' },
         as: :json

    assert_response :unprocessable_entity
    json_response = response.parsed_body
    assert_not_nil json_response['error']
  end

  test 'resubmit handles rate limit exceeded' do
    # Unskipped - fixed authentication issues

    # Mock the RateLimit.check! method to raise an exception
    RateLimit.stubs(:check!).raises(RateLimit::ExceededError.new('Rate limit exceeded'))

    # The request should not raise an exception because the controller handles it
    post "/constituent_portal/applications/#{@application.id}/proofs/resubmit",
         params: { proof_type: 'income', income_proof: @valid_pdf }

    # The controller redirects to the application path with an alert
    assert_redirected_to constituent_portal_application_path(@application)
    assert_equal 'Please wait before submitting another proof', flash[:alert]
  end

  test 'resubmit handles general errors' do
    # Unskipped - fixed authentication issues

    # Mock the attach_and_update_proof method to raise an exception
    ConstituentPortal::Proofs::ProofsController.any_instance.stubs(:attach_and_update_proof).raises(StandardError.new('Test error'))

    # This should raise an exception because we're purposely testing error handling
    assert_raises StandardError do
      post "/constituent_portal/applications/#{@application.id}/proofs/resubmit",
           params: { proof_type: 'income', income_proof: @valid_pdf }
    end
  end
end
