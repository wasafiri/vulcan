require 'test_helper'

module Applications
  class PaperApplicationTypeConsistencyTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin_david)
      @valid_params = {
        constituent: {
          first_name: "John",
          last_name: "Malone",
          email: "john.malone@example.com",
          phone: "2024247676",
          physical_address_1: "12122 long ridge ln",
          city: "bowie",
          state: "MD",
          zip_code: "20715",
          cognition_disability: "1"
        },
        application: {
          household_size: "5",
          annual_income: "29999",
          maryland_resident: "1",
          self_certify_disability: "1",
          medical_provider_name: "doctor",
          medical_provider_phone: "2028321821"
        }
      }
    end

    test "creates constituent with Constituent type" do
      service = PaperApplicationService.new(
        params: @valid_params,
        admin: @admin
      )

      assert service.create, "Failed to create paper application: #{service.errors.join(', ')}"
      
      # Verify the constituent was created with the right type
      constituent = User.find_by(email: "john.malone@example.com")
      assert_not_nil constituent, "Constituent was not created"
      assert_equal "Constituent", constituent.type, "Constituent has incorrect type"
      
      # Ensure account creation email is sent with proper GlobalID
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do |job|
        assert_equal "ApplicationNotificationsMailer", job.arguments[0]
        assert_equal "account_created", job.arguments[1]
      end
    end
  end
end
