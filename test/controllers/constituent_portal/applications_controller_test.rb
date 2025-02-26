require "test_helper"

module ConstituentPortal
  class ApplicationsControllerTest < ActionDispatch::IntegrationTest
    include ActionDispatch::TestProcess::FixtureFile

    setup do
      @user = users(:constituent_john)
      @application = applications(:one)
      @valid_pdf = fixture_file_upload("test/fixtures/files/valid.pdf", "application/pdf")
      @valid_image = fixture_file_upload("test/fixtures/files/valid.jpg", "image/jpeg")

      # Create test files if they don't exist
      fixture_dir = Rails.root.join("test", "fixtures", "files")
      FileUtils.mkdir_p(fixture_dir)

      [ "valid.pdf", "valid.jpg" ].each do |filename|
        file_path = fixture_dir.join(filename)
        unless File.exist?(file_path)
          File.write(file_path, "test content for #{filename}")
        end
      end

      sign_in(@user)
    end

    test "should get index" do
      get constituent_portal_applications_path
      assert_response :success
    end

    test "should get new" do
      get new_constituent_portal_application_path
      assert_response :success
      assert_select "h1", "New Application"

      # Check for updated income proof instructions
      assert_select "p#income-hint", /most recent tax return/
      assert_select "p#income-hint", /current year SSA award letter/
      assert_select "p#income-hint", /less than 2 months old/
      assert_select "p#income-hint", /bank statement showing your SSA deposit/
      assert_select "p#income-hint", /utility bill, it must show your current address/

      # Verify pay stubs are not mentioned
      assert_select "p#income-hint" do |elements|
        elements.each do |element|
          assert_no_match(/pay stub|paystub/i, element.text)
        end
      end
    end

    test "should create application as draft" do
      assert_difference("Application.count") do
        post constituent_portal_applications_path, params: {
          application: {
            maryland_resident: true,
            household_size: 3,
            annual_income: 50000,
            self_certify_disability: true,
            hearing_disability: true
          },
          medical_provider: {
            name: "Dr. Smith",
            phone: "2025551234",
            email: "drsmith@example.com"
          },
          save_draft: "Save Application"
        }
      end

      application = Application.last
      assert_redirected_to constituent_portal_application_path(application)
      assert_equal "draft", application.status
      assert_equal "Dr. Smith", application.medical_provider_name
      assert_equal "2025551234", application.medical_provider_phone
      assert_equal "drsmith@example.com", application.medical_provider_email
    end

    test "should create application as submitted" do
      assert_difference("Application.count") do
        post constituent_portal_applications_path, params: {
          application: {
            maryland_resident: true,
            household_size: 3,
            annual_income: 50000,
            self_certify_disability: true,
            hearing_disability: true,
            residency_proof: @valid_image,
            income_proof: @valid_pdf
          },
          medical_provider: {
            name: "Dr. Smith",
            phone: "2025551234",
            email: "drsmith@example.com"
          },
          submit_application: "Submit Application"
        }
      end

      application = Application.last
      assert_redirected_to constituent_portal_application_path(application)
      assert_equal "in_progress", application.status
      assert application.income_proof.attached?
      assert application.residency_proof.attached?
      assert_equal "not_reviewed", application.income_proof_status
      assert_equal "not_reviewed", application.residency_proof_status
    end

    test "should show application" do
      get constituent_portal_application_path(@application)
      assert_response :success
      assert_select "h1", /Application ##{@application.id}/
    end

    test "should get edit for draft application" do
      @application.update!(status: :draft)
      get edit_constituent_portal_application_path(@application)
      assert_response :success
    end

    test "should not get edit for submitted application" do
      @application.update!(status: :in_progress)
      get edit_constituent_portal_application_path(@application)
      assert_redirected_to constituent_portal_application_path(@application)
      assert_equal "This application has already been submitted and cannot be edited.", flash[:alert]
    end

    test "should update draft application" do
      @application.update!(status: :draft)
      patch constituent_portal_application_path(@application), params: {
        application: {
          household_size: 4,
          annual_income: 60000
        }
      }
      assert_redirected_to constituent_portal_application_path(@application)
      @application.reload
      assert_equal 4, @application.household_size
      assert_equal 60000, @application.annual_income
    end

    test "should submit draft application" do
      @application.update!(status: :draft)
      patch constituent_portal_application_path(@application), params: {
        application: {
          household_size: 4,
          annual_income: 60000,
          medical_provider: {
            name: "Dr. Smith",
            phone: "2025551234",
            email: "drsmith@example.com"
          }
        },
        submit_application: "Submit Application"
      }
      assert_redirected_to constituent_portal_application_path(@application)
      @application.reload
      assert_equal "in_progress", @application.status
    end

    test "should not update submitted application" do
      @application.update!(status: :in_progress)
      patch constituent_portal_application_path(@application), params: {
        application: {
          household_size: 4,
          annual_income: 60000
        }
      }
      assert_redirected_to constituent_portal_application_path(@application)
      assert_equal "This application has already been submitted and cannot be edited.", flash[:alert]
      @application.reload
      assert_not_equal 4, @application.household_size
      assert_not_equal 60000, @application.annual_income
    end

    test "should show validation errors for invalid submission" do
      post constituent_portal_applications_path, params: {
        application: {
          maryland_resident: false,
          household_size: "",
          annual_income: ""
        },
        submit_application: "Submit Application"
      }
      assert_response :unprocessable_entity
      assert_select ".bg-red-50", /prohibited this application from being saved/
      assert_select "li", /Maryland resident You must be a Maryland resident to apply/
      assert_select "li", /Household size can't be blank/
      assert_select "li", /Annual income can't be blank/
    end

    test "should show uploaded document filenames on show page" do
      # First attach files to the application
      @application.income_proof.attach(@valid_pdf)
      @application.residency_proof.attach(@valid_image)
      @application.save!

      get constituent_portal_application_path(@application)
      assert_response :success

      # Check for filenames
      assert_select "p", /Filename: #{File.basename(@valid_pdf.path)}/
      assert_select "p", /Filename: #{File.basename(@valid_image.path)}/
    end
  end
end
