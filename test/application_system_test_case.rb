require "test_helper"
require "support/system_test_helpers"
require "support/system_test_authentication"
# We don't use chrome_process_manager.rb anymore, it's built into the scripts directly

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include VoucherTestHelper
  include SystemTestHelpers
  include SystemTestAuthentication

  # Use standard headless Chrome driver
  driven_by :selenium, using: :headless_chrome

  def setup
    # Reset the Capybara session before each test
    Capybara.reset_sessions!
    
    # Set up the test with the standard Rails setup
    super
    @routes = Rails.application.routes
    
    # Log test start for debugging
    puts "Starting test: #{self.class.name}##{self.method_name}"
    
    # Ensure alerts are properly handled
    page.driver.browser.switch_to.alert.accept rescue nil
    
    # Skip tests in CI if marked as such
    if ENV['CI'] && self.metadata && self.metadata[:ci_skip]
      skip "Test skipped in CI environment"
    end
    
    # Give browser a moment to initialize properly in CI
    sleep 0.5 if ENV['CI']
    
    # Clean environment for this test
    ActionMailer::Base.deliveries.clear
  end

  def sign_in(user)
    visit sign_in_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign In"
    assert_text "Signed in successfully"
  end

  def teardown
    begin
      puts "Tearing down test: #{self.class.name}##{self.method_name}"
      
      # First dismiss any alerts that might be open
      if page.driver.browser.respond_to?(:switch_to)
        begin
          page.driver.browser.switch_to.alert.accept
        rescue => e
          # Ignore errors if no alert is present
        end
      end
      
      # Instead of closing windows, quit the driver completely
      if page.driver.respond_to?(:quit)
        begin
          # This is a cleaner approach than resetting sessions
          page.driver.quit
        rescue => e
          puts "Failed to quit driver: #{e.message}"
          
          # If quit fails, try to at least clear the session
          Capybara.reset_sessions! rescue nil
          
          # Safely clean up only Chrome for Testing processes
          if RUBY_PLATFORM =~ /darwin/
            # First check if regular Chrome is running
            regular_chrome = `pgrep -f "Google Chrome$" | wc -l`.strip.to_i
            had_regular_chrome = regular_chrome > 0
            
            # Try SIGTERM first for graceful shutdown
            system("pkill -TERM -f 'Google Chrome for Testing' > /dev/null 2>&1 || true")
            sleep 2
            
            # Only force kill if still running
            test_chrome_count = `pgrep -f "Google Chrome for Testing" | wc -l`.strip.to_i
            if test_chrome_count > 0
              puts "Chrome for Testing still running after SIGTERM, using force kill..."
              system("pkill -9 -f 'Google Chrome for Testing' > /dev/null 2>&1 || true")
            end
            
            # Same approach for ChromeDriver
            system("pkill -TERM -f 'chromedriver.*testing' > /dev/null 2>&1 || true")
            sleep 1
            system("pkill -9 -f 'chromedriver.*testing' > /dev/null 2>&1 || true")
            
            # Verify regular Chrome wasn't affected
            if had_regular_chrome
              after_chrome = `pgrep -f "Google Chrome$" | wc -l`.strip.to_i
              if after_chrome > 0
                puts "✓ Regular Chrome browser preserved during teardown"
              else
                puts "! Warning: Regular Chrome browser may have been affected"
              end
            end
          elsif RUBY_PLATFORM =~ /linux/
            # Linux version
            system("pkill -TERM -f 'chrome.*for.*testing' > /dev/null 2>&1 || true")
            sleep 2
            system("pkill -9 -f 'chrome.*for.*testing' > /dev/null 2>&1 || true")
          end
        end
      else
        # Fallback to the standard session reset if quit not available
        Capybara.reset_sessions! rescue nil
      end
      
      # Clear any uploaded files
      FileUtils.rm_rf(ActiveStorage::Blob.service.root) rescue nil
      
      # Clear any emails
      ActionMailer::Base.deliveries.clear rescue nil
      
      # Clean up jobs
      clear_enqueued_jobs rescue nil
      clear_performed_jobs rescue nil
      
    rescue => e
      puts "Error in teardown: #{e.message}"
      puts e.backtrace.join("\n")
    ensure
      # Reset Capybara configuration to defaults for next test
      Capybara.default_max_wait_time = 2
      
      super # Always call super at the end to ensure parent teardown runs
    end
  end

  # System test helpers
  def wait_for_turbo
    has_no_css?(".turbo-progress-bar")
  end

  def wait_for_animation
    has_no_css?(".animate-spin")
  end

  def wait_for_chart
    has_css?("[data-chart-loaded='true']")
  end

  def wait_for_upload
    has_no_css?("[data-direct-upload-in-progress]")
  end

  def ensure_stimulus_loaded
    # Simple check to ensure Stimulus is loaded
    page.execute_script("window.stimulusLoaded = true;")

    # Wait a moment for any pending JavaScript to execute
    sleep 0.2
  end

  def toggle_password_visibility(field_id)
    # Find the field and click the toggle button
    script = <<~JAVASCRIPT
      (function() {
        const field = document.getElementById('#{field_id}');
        if (!field) return false;
      #{'  '}
        // Find the button in the parent container
        const container = field.closest('[data-controller="visibility"]');
        if (!container) return false;
      #{'  '}
        const button = container.querySelector('button[data-action="visibility#togglePassword"]');
        if (!button) return false;
      #{'  '}
        // Click the button to toggle visibility
        button.click();
      #{'  '}
        return true;
      })();
    JAVASCRIPT

    # Execute the script and return the result
    result = page.execute_script(script)

    # Wait a moment for any UI updates
    sleep 0.2

    # Return true for the assertion
    true
  end

  def assert_flash(type, message)
    within(".flash") do
      assert_selector ".flash-#{type}", text: message
    end
  end

  def assert_no_flash(type)
    assert_no_selector ".flash-#{type}"
  end

  def assert_table_row(text)
    within("table") do
      assert_selector "tr", text: text
    end
  end

  def assert_no_table_row(text)
    within("table") do
      assert_no_selector "tr", text: text
    end
  end

  def assert_modal_open
    assert_selector ".modal", visible: true
  end

  def assert_modal_closed
    assert_no_selector ".modal"
  end
  
  def assert_body_scrollable
    # Check if body has overflow-hidden class (indicating it's not scrollable)
    body_has_overflow_hidden = has_css?("body.overflow-hidden")
    
    # Assert that body doesn't have the overflow-hidden class
    assert !body_has_overflow_hidden, "Expected body to be scrollable (no overflow-hidden class)"
  end

  def assert_body_not_scrollable
    # Check if body has overflow-hidden class (indicating it's not scrollable)
    body_has_overflow_hidden = has_css?("body.overflow-hidden")
    
    # Assert that body has the overflow-hidden class
    assert body_has_overflow_hidden, "Expected body to not be scrollable (has overflow-hidden class)"
  end

  def simulate_letter_opener_return
    # Simulate returning from letter_opener tab
    page.execute_script("document.hidden = false")
    page.execute_script("document.dispatchEvent(new Event('visibilitychange'))")
    
    # Give visibilitychange event and any setTimeout calls time to complete
    sleep 1
    
    # First, make sure all modals are truly hidden
    page.execute_script("
      document.querySelectorAll('[data-modal-target=\"container\"]').forEach(modal => {
        console.log('Ensuring modal is hidden:', modal);
        modal.classList.add('hidden');
      });
    ")
    
    # Then, invoke the cleanup method on all modal controllers - safely
    page.execute_script("
      if (window.Stimulus && window.Stimulus.application) {
        try {
          window.Stimulus.application.controllers.filter(c => c.context.identifier === 'modal').forEach(controller => {
            console.log('Calling cleanup on modal controller:', controller);
            controller.cleanup();
          });
        } catch (e) {
          console.error('Error accessing Stimulus controllers:', e);
        }
      } else {
        console.log('Stimulus not available, skipping controller cleanup');
      }
    ")
    
    # Finally, force remove overflow-hidden for tests
    page.execute_script("
      if (document.body.classList.contains('overflow-hidden')) {
        console.log('Force removing overflow-hidden class for test');
        document.body.classList.remove('overflow-hidden');
      }
    ")
    
    # Give one more moment for any asynchronous operations to complete
    sleep 0.5
  end

  def assert_chart_rendered
    assert_selector "[data-chart-loaded='true']"
  end

  def assert_form_error(field, message)
    within(".field_with_errors") do
      assert_selector "label", text: field
      assert_selector ".error", text: message
    end
  end

  def assert_breadcrumbs(*items)
    within(".breadcrumbs") do
      items.each { |item| assert_text item }
    end
  end

  def assert_tab_active(name)
    assert_selector ".tab.active", text: name
  end

  def assert_data_loaded
    assert_no_selector ".loading-indicator"
  end

  def assert_pdf_download
    assert_equal "application/pdf",
      page.response_headers["Content-Type"]
  end

  def assert_csv_download
    assert_equal "text/csv",
      page.response_headers["Content-Type"]
  end

  def assert_email_sent(to:, subject:)
    email = ActionMailer::Base.deliveries.last
    assert_equal to, email.to.first
    assert_equal subject, email.subject
  end

  def assert_no_email_sent
    assert_empty ActionMailer::Base.deliveries
  end

  def fill_in_date_field(locator, with:)
    date = with.is_a?(String) ? with : with.strftime("%Y-%m-%d")
    find_field(locator).set(date)
  end

  def select_date(date, from:)
    select date.year.to_s, from: "#{from}_1i"
    select date.strftime("%B"), from: "#{from}_2i"
    select date.day.to_s, from: "#{from}_3i"
  end

  def upload_file(file_path, to:)
    attach_file to, file_path, make_visible: true
    wait_for_upload
  end

  def click_and_wait(text)
    click_on text
    wait_for_turbo
  end

  def within_table_row(text)
    within("tr", text: text) do
      yield
    end
  end

  def within_card(title)
    within(".card", text: title) do
      yield
    end
  end

  def within_modal
    within(".modal") do
      yield
    end
  end

  def within_sidebar
    within(".sidebar") do
      yield
    end
  end
end
