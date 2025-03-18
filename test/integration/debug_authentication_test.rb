# frozen_string_literal: true

require "test_helper"

# Debug Authentication Test
#
# This test is specifically designed to debug authentication issues in the test environment.
# It tests various authentication scenarios and provides detailed debug output.
class DebugAuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    # Enable debug logging for authentication issues
    ENV["DEBUG_AUTH"] = "true"

    # Set up test data
    @user = users(:constituent_john)
  end

  # Test the basic sign_in helper with detailed debugging
  test "debug sign_in helper" do
    # Sign in the user
    sign_in(@user)

    # Debug output
    puts "\n\n=== DEBUG: After sign_in ==="
    puts "Cookies: #{cookies.inspect}"
    puts "Session token in cookies: #{cookies[:session_token]}"
    if cookies.respond_to?(:signed)
      puts "Signed session token: #{cookies.signed[:session_token]}"
    end

    # Verify cookie is set
    assert_not_nil cookies[:session_token], "Session token cookie not set"

    # Make a request to a protected page
    get constituent_portal_applications_path

    # Debug output
    puts "\n=== DEBUG: After accessing protected page ==="
    puts "Response status: #{response.status}"
    puts "Response location: #{response.location}" if response.redirect?
    puts "Response body excerpt: #{response.body[0..100]}..." if response.body.present?

    # If redirected to sign in, try to understand why
    if response.redirect? && response.location.include?("sign_in")
      puts "\n=== DEBUG: Authentication failed, investigating... ==="

      # Check if the session record exists
      session_record = Session.find_by(session_token: cookies[:session_token])
      if session_record
        puts "Session record found with token: #{cookies[:session_token]}"
        puts "Session user ID: #{session_record.user_id}"
        puts "Session created at: #{session_record.created_at}"
      else
        puts "No session record found with token: #{cookies[:session_token]}"
      end

      # Check if the current_user method is working
      get root_path
      puts "\n=== DEBUG: Checking current_user method ==="
      if response.body.include?("Sign Out") || response.body.include?("Logout")
        puts "User appears to be signed in (found logout link)"
      else
        puts "User does not appear to be signed in (no logout link found)"
      end
    end
  end

  # Test the checkbox test approach with detailed debugging
  test "debug checkbox test approach" do
    # Use the same approach as the checkbox test
    @user = users(:constituent_john)
    sign_in(@user)

    # Debug output
    puts "\n\n=== DEBUG: After checkbox test approach sign_in ==="
    puts "Cookies: #{cookies.inspect}"

    # Simulate a form submission like in the checkbox test
    post constituent_portal_applications_path, params: {
      application: {
        maryland_resident: true,
        household_size: 3,
        annual_income: 50000,
        self_certify_disability: [ "0", "1" ],
        hearing_disability: true
      },
      medical_provider: {
        name: "Dr. Smith",
        phone: "2025551234",
        email: "drsmith@example.com"
      },
      save_draft: "Save Application"
    }

    # Debug output
    puts "\n=== DEBUG: After form submission ==="
    puts "Response status: #{response.status}"
    puts "Response location: #{response.location}" if response.redirect?

    # Check that the application was created
    if response.redirect?
      # Get the newly created application
      application = Application.last

      if application
        puts "Application created with ID: #{application.id}"
        puts "self_certify_disability value: #{application.self_certify_disability.inspect}"
      else
        puts "No application was created"
      end
    else
      puts "Form submission failed with status: #{response.status}"
      puts "Response body excerpt: #{response.body[0..100]}..." if response.body.present?
    end
  end

  # Test direct cookie manipulation with detailed debugging
  test "debug direct cookie manipulation" do
    # Create a session directly
    session = @user.sessions.create!(
      user_agent: "Rails Testing",
      ip_address: "127.0.0.1"
    )

    puts "\n\n=== DEBUG: Created session ==="
    puts "Session token: #{session.session_token}"
    puts "Session user ID: #{session.user_id}"

    # Set the cookie directly
    cookies[:session_token] = session.session_token
    if cookies.respond_to?(:signed)
      cookies.signed[:session_token] = { value: session.session_token, httponly: true }
    end

    # Debug output
    puts "\n=== DEBUG: After setting cookies ==="
    puts "Cookies: #{cookies.inspect}"

    # Verify we can access a protected page
    get constituent_portal_applications_path

    # Debug output
    puts "\n=== DEBUG: After accessing protected page ==="
    puts "Response status: #{response.status}"
    puts "Response location: #{response.location}" if response.redirect?

    # If redirected to sign in, try to understand why
    if response.redirect? && response.location.include?("sign_in")
      puts "\n=== DEBUG: Authentication failed, investigating... ==="

      # Check if the session record exists
      session_record = Session.find_by(session_token: cookies[:session_token])
      if session_record
        puts "Session record found with token: #{cookies[:session_token]}"
        puts "Session user ID: #{session_record.user_id}"
        puts "Session created at: #{session_record.created_at}"
      else
        puts "No session record found with token: #{cookies[:session_token]}"
      end
    end
  end

  # Test the controller's current_user method directly
  test "debug controller current_user method" do
    # Create a session directly
    session = @user.sessions.create!(
      user_agent: "Rails Testing",
      ip_address: "127.0.0.1"
    )

    # Set both signed and unsigned cookies
    cookies[:session_token] = session.session_token
    if cookies.respond_to?(:signed)
      cookies.signed[:session_token] = { value: session.session_token, httponly: true }
    end

    # Access a page to get a controller instance
    get constituent_portal_applications_path

    # Debug output
    puts "\n\n=== DEBUG: After accessing page ==="
    puts "Response status: #{response.status}"
    puts "Response location: #{response.location}" if response.redirect?

    # If redirected to sign in, try to understand why
    if response.redirect? && response.location.include?("sign_in")
      puts "\n=== DEBUG: Authentication failed, investigating... ==="

      # Check if the session record exists
      session_record = Session.find_by(session_token: cookies[:session_token])
      if session_record
        puts "Session record found with token: #{cookies[:session_token]}"
        puts "Session user ID: #{session_record.user_id}"
        puts "Session created at: #{session_record.created_at}"
      else
        puts "No session record found with token: #{cookies[:session_token]}"
      end

      # Try to access the controller's current_user method
      puts "\n=== DEBUG: Trying to access current_user method ==="
      begin
        current_user = @controller.send(:current_user)
        puts "current_user method returned: #{current_user.inspect}"
      rescue StandardError => e
        puts "Error accessing current_user method: #{e.message}"
      end
    end
  end
end
