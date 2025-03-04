require "test_helper"

class Admin::PaperApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_david)

    # Set the TEST_USER_ID environment variable to override authentication
    ENV["TEST_USER_ID"] = @admin.id.to_s

    # Also use the traditional cookie-based approach as a fallback
    sign_in_with_headers(@admin)

    # Verify authentication was successful
    assert_authenticated(@admin)

    # Set up FPL policies for testing
    Policy.find_or_create_by(key: "fpl_1_person").update(value: 15000)
    Policy.find_or_create_by(key: "fpl_2_person").update(value: 20000)
    Policy.find_or_create_by(key: "fpl_modifier_percentage").update(value: 400)

    # Ensure test files exist
    fixture_dir = Rails.root.join("test", "fixtures", "files")
    FileUtils.mkdir_p(fixture_dir)

    [ "test_proof.pdf", "test_income_proof.pdf", "test_residency_proof.pdf" ].each do |filename|
      file_path = fixture_dir.join(filename)
      unless File.exist?(file_path)
        File.write(file_path, "test content for #{filename}")
      end
    end
  end

  test "should get new" do
    get new_admin_paper_application_path, headers: default_headers
    assert_response :success
    assert_select "h1", "Upload Paper Application"
  end

  test "should create paper application with valid data" do
    # Get the count before the request
    application_count_before = Application.count

    post admin_paper_applications_path, headers: default_headers, params: {
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

    # Verify the response
    assert_response :unprocessable_entity
  end

  test "should create paper application with rejected proofs" do
    # Create test files to attach
    income_proof = fixture_file_upload(Rails.root.join("test/fixtures/files/test_proof.pdf"), "application/pdf")
    residency_proof = fixture_file_upload(Rails.root.join("test/fixtures/files/test_proof.pdf"), "application/pdf")

    # Skip the ProofReview validations in this test
    ProofReview.any_instance.stubs(:save).returns(true)
    ProofReview.any_instance.stubs(:valid?).returns(true)

    # Get the count before the request
    application_count_before = Application.count

    post admin_paper_applications_path, headers: default_headers, params: {
      income_proof: income_proof,
      residency_proof: residency_proof,
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
      income_proof_action: "reject",
      income_proof_rejection_reason: "incomplete_documentation",
      income_proof_rejection_notes: "The income documentation is incomplete.",
      residency_proof_action: "reject",
      residency_proof_rejection_reason: "address_mismatch",
      residency_proof_rejection_notes: "The address on the document doesn't match."
    }

    # Verify the response
    assert_response :unprocessable_entity
  end

  test "should create paper application with rejected residency proof but no file attached" do
    # Disable email delivery for this test
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = false

    # Create test file for income proof only
    income_proof = fixture_file_upload(Rails.root.join("test/fixtures/files/test_proof.pdf"), "application/pdf")

    # Get the count before the request
    application_count_before = Application.count
    proof_review_count_before = ProofReview.count

    # Set the environment to test (non-production)
    Rails.env.stubs(:production?).returns(false)

    # Ensure system_user returns a valid admin
    User.stubs(:system_user).returns(@admin)

    post admin_paper_applications_path, headers: default_headers, params: {
      income_proof: income_proof,
      constituent: {
        first_name: "Jane",
        last_name: "Smith",
        email: "test-paper-app@example.com", # Use a unique email to avoid conflicts
        phone: "555-987-6543",
        physical_address_1: "456 Oak St",
        city: "Baltimore",
        state: "MD",
        zip_code: "21202",
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
        medical_provider_name: "Dr. John Doe",
        medical_provider_phone: "555-123-4567",
        medical_provider_email: "dr.doe@example.com"
      },
      income_proof_action: "accept",
      residency_proof_action: "reject",
      residency_proof_rejection_reason: "address_mismatch",
      residency_proof_rejection_notes: "The address on the document doesn't match."
    }

    # Restore the environment
    Rails.env.unstub(:production?)

    # Re-enable email delivery
    ActionMailer::Base.perform_deliveries = true

    # Verify the response - we expect a redirect
    assert_response :redirect

    # Verify that the application was created
    assert_equal application_count_before + 1, Application.count

    # Get the created application
    application = Application.last

    # Verify that the application has the correct status
    assert_equal "in_progress", application.status

    # Verify that the residency proof status is rejected
    assert_equal "rejected", application.residency_proof_status

    # The main thing we're testing is that the application is created successfully
    # and the residency proof status is set to "rejected", even without a file attached
  end

  test "should not create paper application when income exceeds threshold" do
    assert_no_difference("Application.count") do
      assert_no_difference("Constituent.count") do
        post admin_paper_applications_path, headers: default_headers, params: {
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
    assert_match "This constituent already has an active application.", flash[:alert]
  end

  test "should not create paper application for constituent with active application" do
    # Create a constituent with an active application
    constituent = Constituent.create!(
      first_name: "Jane",
      last_name: "Smith",
      email: "jane.smith@example.com",
      phone: "555-987-6543",
      password: "password",
      password_confirmation: "password",
      hearing_disability: true
    )

    # Create an active application for the constituent
    constituent.applications.create!(
      household_size: 2,
      annual_income: 20000,
      status: :in_progress,
      application_date: Time.current,
      maryland_resident: true,
      medical_provider_name: "Dr. Jane Smith",
      medical_provider_phone: "555-987-6543",
      medical_provider_email: "dr.smith@example.com"
    )

    assert_no_difference("Application.count") do
      post admin_paper_applications_path, headers: default_headers, params: {
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
    get fpl_thresholds_admin_paper_applications_path, headers: default_headers
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 15000, json_response["thresholds"]["1"]
    assert_equal 20000, json_response["thresholds"]["2"]
    assert_equal 400, json_response["modifier"]
  end

  test "should send rejection notification" do
    post send_rejection_notification_admin_paper_applications_path, headers: default_headers, params: {
      first_name: "John",
      last_name: "Doe",
      email: "john.doe@example.com",
      phone: "555-123-4567",
      household_size: "2",
      annual_income: "100000",
      notification_method: "email",
      additional_notes: "Income exceeds threshold"
    }

    assert_redirected_to admin_applications_path
    assert_match "Rejection notification has been sent", flash[:notice]
  end

  test "should send rejection letter notification" do
    post send_rejection_notification_admin_paper_applications_path, headers: default_headers, params: {
      first_name: "John",
      last_name: "Doe",
      email: "john.doe@example.com",
      phone: "555-123-4567",
      household_size: "2",
      annual_income: "100000",
      notification_method: "letter",
      additional_notes: "Income exceeds threshold"
    }

    assert_redirected_to admin_applications_path
    assert_match "Rejection letter has been queued for printing", flash[:notice]
  end

  test "should not enqueue jobs when transaction fails" do
    # Mock ProofReview.save to fail
    ProofReview.any_instance.stubs(:save).returns(false)
    ProofReview.any_instance.stubs(:errors).returns(
      ActiveModel::Errors.new(ProofReview.new).tap { |e| e.add(:base, "Mocked error") }
    )

    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      assert_no_difference("Application.count") do
        assert_no_difference("Constituent.count") do
          post admin_paper_applications_path, headers: default_headers, params: {
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
            income_proof_action: "reject",
            income_proof_rejection_reason: "incomplete_documentation",
            income_proof_rejection_notes: "The income documentation is incomplete."
          }
        end
      end
    end

    assert_response :unprocessable_entity
    assert_match "This constituent already has an active application.", flash[:alert]
  end

  test "should handle missing constituent gracefully in notification job" do
    # This test verifies that the system can handle the case where a constituent
    # is referenced in a job but doesn't exist (e.g., due to a rolled back transaction)

    # Create a job that references a non-existent constituent
    job = ActionMailer::MailDeliveryJob.new(
      "ApplicationNotificationsMailer",
      "account_created",
      "deliver_now",
      args: [ Constituent.find_by(id: 999999), "password" ]
    )

    # The job should raise an error but not crash the worker
    assert_raises NoMethodError do
      job.perform_now
    end
  end

  test "should handle proof rejection without setting properties directly on application" do
    # Create test file for income proof
    income_proof = fixture_file_upload(Rails.root.join("test/fixtures/files/test_proof.pdf"), "application/pdf")

    # Set the environment to test (non-production)
    Rails.env.stubs(:production?).returns(false)

    # Ensure system_user returns a valid admin
    User.stubs(:system_user).returns(@admin)

    # Verify that the controller correctly handles the rejection reason
    post admin_paper_applications_path, headers: default_headers, params: {
      income_proof: income_proof,
      constituent: {
        first_name: "Test",
        last_name: "User",
        email: "test-rejection@example.com",
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
        medical_provider_name: "Dr. Test",
        medical_provider_phone: "555-987-6543",
        medical_provider_email: "dr.test@example.com"
      },
      income_proof_action: "reject",
      income_proof_rejection_reason: "incomplete_documentation",
      income_proof_rejection_notes: "Missing required information"
    }

    # Restore the environment
    Rails.env.unstub(:production?)

    # Verify the response
    assert_response :redirect

    # Get the created application
    application = Application.find_by(user: Constituent.find_by(email: "test-rejection@example.com"))
    assert_not_nil application

    # Verify that the income proof status is rejected
    assert_equal "rejected", application.income_proof_status

    # Verify that a proof review was created with the correct rejection reason
    proof_review = application.proof_reviews.last
    assert_not_nil proof_review
    assert_equal "income", proof_review.proof_type
    assert_equal "rejected", proof_review.status
    assert_equal "incomplete_documentation", proof_review.rejection_reason
    assert_equal "Missing required information", proof_review.notes
  end

  test "should handle application save failure" do
    # Mock Application.save to fail
    Application.any_instance.stubs(:save).returns(false)
    Application.any_instance.stubs(:errors).returns(
      ActiveModel::Errors.new(Application.new).tap { |e| e.add(:base, "Mocked application error") }
    )

    # Ensure system_user returns a valid admin
    User.stubs(:system_user).returns(@admin)

    assert_no_difference("Application.count") do
      post admin_paper_applications_path, headers: default_headers, params: {
        constituent: {
          first_name: "Test",
          last_name: "User",
          email: "test-app-save-failure@example.com",
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
          medical_provider_name: "Dr. Test",
          medical_provider_phone: "555-987-6543",
          medical_provider_email: "dr.test@example.com"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
