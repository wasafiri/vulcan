# frozen_string_literal: true

# SystemTestAuthentication
#
# This module provides simplified and robust authentication capabilities for system tests.
# It focuses on UI-based sign-in and sign-out with minimal error recovery logic.
module SystemTestAuthentication
  extend ActiveSupport::Concern
  include AuthenticationCore

  # Signs a user in through the UI.
  def system_test_sign_in(user, verify_path: nil)
    # Prevent sign-in attempts if already authenticated.
    if page.has_text?('Sign Out', wait: 0)
      puts "Already signed in. Skipping sign-in for #{user.email}."
      return
    end

    # Visit sign-in page using Capybara's visit and wait helpers
    visit sign_in_path
    wait_for_network_idle
    wait_for_stimulus_controller

    # Set session variable to bypass 2FA for system tests when using RackTest driver
    page.set_rack_session(skip_2fa: true) if page.driver.is_a?(Capybara::RackTest::Driver)

    # Wait for form to be ready with more specific selectors
    assert_selector('form[action="/sign_in"]', wait: 10)

    # Use a more robust form filling approach
    perform_enqueued_jobs do
      within('form[action="/sign_in"]') do
        fill_in 'email-input', with: user.email
        fill_in 'password-input', with: 'password123'
        click_button 'Sign In'
      end
    end

    # Wait for Turbo and any network activity to settle before checking redirect
    wait_for_network_idle

    # Handle different redirect scenarios based on verify_path
    if verify_path.present?
      # For 2FA flows, we expect to be redirected to verification page
      assert_current_path(verify_path, wait: 10)
      puts "Successfully redirected to verification page for #{user.email}"
    elsif current_path.match?(%r{/two_factor_authentication/verify})
      # Check if user has 2FA and we're on a verification page
      puts "User #{user.email} has 2FA enabled, on verification page: #{current_path}"
    # Don't assert dashboard path - let the test handle the verification flow
    else
      # For normal sign-in, we expect to be redirected to dashboard
      expected_dashboard_path = user_dashboard_path(user)
      assert_current_path(expected_dashboard_path, wait: 10)
      # Assert that the sign-in was successful by looking for the dashboard header.
      assert_selector 'h1', text: 'Dashboard', wait: 10
      puts "Successfully signed in as #{user.email}"
    end
  rescue Capybara::ElementNotFound => e
    puts "Sign-in failed: #{e.message}. Current page: #{current_path}"
    take_screenshot('sign_in_failure')
    raise
  rescue Ferrum::NodeNotFoundError => e
    puts "Node not found error during sign-in: #{e.message}. Current page: #{current_path}"
    take_screenshot('node_not_found_failure')
    # Retry once with fresh session
    puts 'Retrying sign-in with fresh session...'
    Capybara.reset_sessions!
    clear_pending_network_connections

    # Retry the sign-in process once
    visit sign_in_path
    wait_for_network_idle

    within('form[action="/sign_in"]') do
      fill_in 'email-input', with: user.email
      fill_in 'password-input', with: 'password123'
      click_button 'Sign In'
    end

    # Wait for redirect and handle 2FA or dashboard
    wait_for_network_idle

    # Apply same logic as main flow for retry
    if verify_path.present?
      assert_current_path(verify_path, wait: 10)
      puts "Successfully redirected to verification page for #{user.email} on retry"
    elsif current_path.match?(%r{/two_factor_authentication/verify})
      puts "User #{user.email} has 2FA enabled, on verification page: #{current_path} on retry"
    else
      assert_selector 'h1', text: 'Dashboard', wait: 10
      puts "Successfully signed in as #{user.email} on retry"
    end
  end

  def skip_2fa_and_sign_in(user)
    # Set a session variable to bypass 2FA. This requires controller cooperation.
    # Only works with RackTest driver, not Cuprite
    page.set_rack_session(skip_2fa: true) if page.driver.is_a?(Capybara::RackTest::Driver)
    system_test_sign_in(user)
  end

  # Signs the user out and resets the session state.
  def system_test_sign_out
    # Only try to sign out if a sign-out link/button is present.
    if page.has_link?('Sign Out', wait: 1)
      click_link 'Sign Out'
      wait_for_network_idle
      assert_current_path(sign_in_path, wait: 10)
    elsif page.has_button?('Sign Out', wait: 1)
      click_button 'Sign Out'
      wait_for_network_idle
      assert_current_path(sign_in_path, wait: 10)
    end
  rescue Ferrum::DeadBrowserError
    # If the browser is already dead, we can't interact with it.
    puts 'Browser was already dead during sign-out. Continuing teardown.'
  ensure
    # Always clear identity and reset sessions to guarantee a clean state.
    clear_test_identity
    Capybara.reset_sessions!
  end

  private

  # Determine the correct dashboard path based on user type
  def user_dashboard_path(user)
    case user.type
    when 'Users::Administrator'
      admin_dashboard_path
    when 'Users::Constituent'
      constituent_portal_dashboard_path
    when 'Users::Evaluator'
      evaluators_dashboard_path
    when 'Users::Trainer'
      trainers_dashboard_path
    when 'Users::Vendor'
      vendor_dashboard_path
    else
      # Default to root path if user type is unknown
      root_path
    end
  end

  # Robust visit method that handles pending connections gracefully
  def visit_with_retry(path, max_retries: 3)
    success = false
    max_retries.times do |attempt|
      visit path
      wait_for_network_idle if respond_to?(:wait_for_network_idle)
      success = true
      break # Success
    rescue Ferrum::PendingConnectionsError => e
      puts "Visit attempt #{attempt + 1}: Pending connections error: #{e.message}"
      if attempt < max_retries - 1
        puts 'Retrying after clearing sessions...'
        clear_pending_network_connections
        # Use Capybara's waiting instead of static wait
        using_wait_time(2) do
          assert_selector 'body', wait: 2
        end
      else
        puts "Failed after #{max_retries} attempts, continuing..."
        # Don't raise - let the test continue and potentially fail on assertions
      end
    end
    success
  end
end
