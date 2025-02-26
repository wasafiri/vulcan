require "test_helper"

class Admin::PaperApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    sign_in @admin

    # Set up FPL policies for testing
    Policy.find_or_create_by(key: "fpl_1_person").update(value: 15000)
    Policy.find_or_create_by(key: "fpl_2_person").update(value: 20000)
    Policy.find_or_create_by(key: "fpl_modifier_percentage").update(value: 400)
  end

  test "should get new" do
    get new_admin_paper_application_path
    assert_response :success
    assert_select "h1", "Upload Paper Application"
  end

  test "should create paper application with valid data" do
    assert_difference("Application.count") do
      assert_difference("Constituent.count") do
        post admin_paper_applications_path, params: {
          constituent: {
            first_name: "John",
            last_name: "Doe",
            email: "john.doe@example.com",
            phone: "555-123-4567",
            physical_address_1: "123 Main St",
            city: "Baltimore",
            state: "MD",
            zip_code: "21201",
            hearing_disability: "1"
          },
          application: {
            household_size: 2,
            annual_income: 20000,
            maryland_resident: "1",
            self_certify_disability: "1",
            terms_accepted: "1",
            information_verified: "1",
            medical_release_authorized: "1",
            medical_provider_name: "Dr. Jane Smith",
            medical_provider_phone: "555-987-6543",
            medical_provider_email: "dr.smith@example.com"
          },
          income_proof_action: "accept",
          residency_proof_action: "accept"
        }
      end
    end

    assert_redirected_to admin_application_path(Application.last)
    assert_equal "Paper application successfully submitted.", flash[:notice]
  end

  test "should not create paper application when income exceeds threshold" do
    assert_no_difference("Application.count") do
      assert_no_difference("Constituent.count") do
        post admin_paper_applications_path, params: {
          constituent: {
            first_name: "John",
            last_name: "Doe",
            email: "john.doe@example.com",
            phone: "555-123-4567",
            physical_address_1: "123 Main St",
            city: "Baltimore",
            state: "MD",
            zip_code: "21201"
          },
          application: {
            household_size: 2,
            annual_income: 100000, # Exceeds 400% of $20,000
            maryland_resident: "1",
            self_certify_disability: "1",
            terms_accepted: "1",
            information_verified: "1",
            medical_release_authorized: "1"
          }
        }
      end
    end

    assert_response :unprocessable_entity
    assert_match "Income exceeds the maximum threshold", flash[:alert]
  end

  test "should not create paper application for constituent with active application" do
    # Create a constituent with an active application
    constituent = Constituent.create!(
      first_name: "Jane",
      last_name: "Smith",
      email: "jane.smith@example.com",
      phone: "555-987-6543",
      password: "password",
      password_confirmation: "password"
    )

    # Create an active application for the constituent
    constituent.applications.create!(
      household_size: 2,
      annual_income: 20000,
      status: :in_progress,
      application_date: Time.current
    )

    assert_no_difference("Application.count") do
      post admin_paper_applications_path, params: {
        constituent: {
          first_name: constituent.first_name,
          last_name: constituent.last_name,
          email: constituent.email,
          phone: constituent.phone,
          physical_address_1: "123 Main St",
          city: "Baltimore",
          state: "MD",
          zip_code: "21201"
        },
        application: {
          household_size: 2,
          annual_income: 20000,
          maryland_resident: "1",
          self_certify_disability: "1",
          terms_accepted: "1",
          information_verified: "1",
          medical_release_authorized: "1"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_match "already has an active application", flash[:alert]
  end

  test "should get fpl_thresholds" do
    get fpl_thresholds_admin_paper_applications_path
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 15000, json_response["thresholds"]["1"]
    assert_equal 20000, json_response["thresholds"]["2"]
    assert_equal 400, json_response["modifier"]
  end

  test "should send rejection notification" do
    assert_enqueued_email_with ApplicationNotificationsMailer, :income_threshold_exceeded do
      post send_rejection_notification_admin_paper_applications_path, params: {
        first_name: "John",
        last_name: "Doe",
        email: "john.doe@example.com",
        phone: "555-123-4567",
        household_size: "2",
        annual_income: "100000",
        notification_method: "email",
        additional_notes: "Income exceeds threshold"
      }
    end

    assert_redirected_to admin_applications_path
    assert_match "Rejection notification has been sent", flash[:notice]
  end
end
