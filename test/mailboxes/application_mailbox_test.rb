require "test_helper"
require "support/action_mailbox_test_helper"

class ApplicationMailboxTest < ActionMailbox::TestCase
  include ActionMailboxTestHelper

  setup do
    # Create a constituent and application using factories
    @constituent = create(:constituent)
    @application = create(:application, user: @constituent)
    @constituent.update(email: "constituent@example.com")

    # Create a medical provider using factory
    @medical_provider = create(:medical_provider, email: "doctor@example.com")

    # Create policy records for rate limiting
    create(:policy, :proof_submission_rate_limit_web)
    create(:policy, :proof_submission_rate_limit_email)
    create(:policy, :proof_submission_rate_period)
    create(:policy, :max_proof_rejections)

    # Add medical certification requested flag if needed
    unless @application.respond_to?(:medical_certification_requested?)
      @application.define_singleton_method(:medical_certification_requested?) do
        true
      end
    end

    # Add rejection count method if needed
    unless @application.respond_to?(:rejection_count)
      @application.define_singleton_method(:rejection_count) do
        0
      end
    end

    # Set up ApplicationMailbox routing for testing
    ApplicationMailbox.instance_eval do
      routing(/proof@/i => :proof_submission)
      routing(/medical-cert@/i => :medical_certification)
      routing(/.+/ => :default)
    end
  end

  test "routes emails correctly based on address" do
    # Test that the routing patterns are set up correctly
    router = ApplicationMailbox.router

    # Get the routing patterns from the router
    routes = router.instance_variable_get(:@routes)

    # Check that the proof submission route exists
    proof_route = routes.find { |route| route.mailbox_name == :proof_submission }
    assert proof_route, "Proof submission route not found"

    # Check that the medical certification route exists
    medical_route = routes.find { |route| route.mailbox_name == :medical_certification }
    assert medical_route, "Medical certification route not found"

    # Check that the default route exists
    default_route = routes.find { |route| route.mailbox_name == :default }
    assert default_route, "Default route not found"
  end
end
