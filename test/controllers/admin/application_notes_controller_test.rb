require "test_helper"

class Admin::ApplicationNotesControllerTest < ActionDispatch::IntegrationTest
  include AuthenticationTestHelper

  setup do
    @admin = create(:user, type: "Admin")
    @application = create(:application)

    # Create a session for the admin user
    @session = @admin.sessions.create!(
      user_agent: "Rails Testing",
      ip_address: "127.0.0.1"
    )

    # Set the session token in the cookies
    cookies[:session_token] = @session.session_token
  end

  test "should create internal note" do
    assert_difference("ApplicationNote.count") do
      post admin_application_notes_path(@application), params: {
        application_note: {
          content: "This is an internal note",
          internal_only: true
        }
      }
    end

    assert_redirected_to admin_application_path(@application)
    assert_equal "Note added successfully.", flash[:notice]

    note = ApplicationNote.last
    assert_equal @application, note.application
    assert_equal @admin, note.admin
    assert_equal "This is an internal note", note.content
    assert note.internal_only
  end

  test "should create public note" do
    assert_difference("ApplicationNote.count") do
      post admin_application_notes_path(@application), params: {
        application_note: {
          content: "This is a public note",
          internal_only: false
        }
      }
    end

    assert_redirected_to admin_application_path(@application)
    assert_equal "Note added successfully.", flash[:notice]

    note = ApplicationNote.last
    assert_equal @application, note.application
    assert_equal @admin, note.admin
    assert_equal "This is a public note", note.content
    assert_not note.internal_only
  end

  test "should not create note with empty content" do
    assert_no_difference("ApplicationNote.count") do
      post admin_application_notes_path(@application), params: {
        application_note: {
          content: "",
          internal_only: true
        }
      }
    end

    assert_redirected_to admin_application_path(@application)
    assert_match /Failed to add note/, flash[:alert]
  end

  # Authentication is skipped in test environment in Admin::BaseController
  # So we can't test authentication requirements directly
  test "should set current user from authentication" do
    # Verify that the current_user is set correctly
    post admin_application_notes_path(@application), params: {
      application_note: {
        content: "Test note with authentication",
        internal_only: true
      }
    }

    assert_redirected_to admin_application_path(@application)

    note = ApplicationNote.last
    assert_equal @admin.id, note.admin_id, "Note should be created with the authenticated admin user"
  end
end
