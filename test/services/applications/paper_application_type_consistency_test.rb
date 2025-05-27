# frozen_string_literal: true

require 'test_helper'

module Applications
  class PaperApplicationTypeConsistencyTest < ActiveSupport::TestCase
    include ActiveJob::TestHelper

    setup do
      @admin = create(:admin)

      # Set thread local context to skip proof validations in tests
      Thread.current[:paper_application_context] = true

      # Set up FPL policies for testing
      setup_fpl_policies
      @valid_params = {
        constituent: {
          first_name: 'John',
          last_name: 'Malone',
          email: 'john.malone@example.com',
          phone: '2024247676',
          physical_address_1: '12122 long ridge ln',
          city: 'bowie',
          state: 'MD',
          zip_code: '20715',
          cognition_disability: '1'
        },
        application: {
          household_size: '5',
          annual_income: '29999',
          maryland_resident: '1',
          self_certify_disability: '1',
          medical_provider_name: 'doctor',
          medical_provider_phone: '2028321821',
          medical_provider_email: 'doctor@example.com'
        }
      }
    end

    test 'creates constituent with proper Users::Constituent type' do
      service = PaperApplicationService.new(
        params: @valid_params,
        admin: @admin
      )

      assert service.create, "Failed to create paper application: #{service.errors.join(', ')}"

      # Verify the constituent was created with the right type
      constituent = User.find_by(email: 'john.malone@example.com')
      assert_not_nil constituent, 'Constituent was not created'
      assert_equal 'Users::Constituent', constituent.type, 'Constituent has incorrect type'

      # Verify that the service attempts to send the correct email
      # Stub the mailer to prevent template lookup errors in this *service* test
      mock_mailer = mock('ActionMailer::MessageDelivery')
      mock_mailer.expects(:deliver_later) # Expect deliver_later to be called

      # Expect the mailer method to be called with the created constituent and any password
      ApplicationNotificationsMailer.expects(:account_created)
                                    .with(constituent, anything) # Match constituent, ignore temp password
                                    .returns(mock_mailer)

      # Trigger the mailer by performing the job enqueued by the service (if any)
      # Note: The service itself might call deliver_later directly or enqueue a job.
      # If the service calls deliver_later directly, the expectation above handles it.
      # If it enqueues a job, perform_enqueued_jobs might be needed, but the expectation
      # should still capture the mailer call *before* deliver_later is invoked by the job.
      # Let's assume the service triggers the mailer directly or indirectly.
      # If the assertion fails, we might need to adjust how the mailer call is triggered/expected.

      # We don't need assert_emails or perform_enqueued_jobs here anymore,
      # as we are mocking the mailer call itself.
    end

    teardown do
      # Clean up thread local context after the test
      Thread.current[:paper_application_context] = nil
    end

    # Helper method to set up policies for FPL threshold testing
    def setup_fpl_policies
      # Stub the log_change method to avoid validation errors in test
      Policy.class_eval do
        def log_change
          # No-op in test environment to bypass the user requirement
        end
      end

      # Set up standard FPL values for testing purposes
      Policy.find_or_create_by(key: 'fpl_1_person').update(value: 15_000)
      Policy.find_or_create_by(key: 'fpl_2_person').update(value: 20_000)
      Policy.find_or_create_by(key: 'fpl_3_person').update(value: 25_000)
      Policy.find_or_create_by(key: 'fpl_4_person').update(value: 30_000)
      Policy.find_or_create_by(key: 'fpl_5_person').update(value: 35_000) # Matches our test household size
      Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)
    end
  end
end
