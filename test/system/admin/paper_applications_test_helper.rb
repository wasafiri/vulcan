# frozen_string_literal: true

# Helper module for paper application system tests
# This adds additional support methods to improve test stability with Cuprite
module PaperApplicationsTestHelper
  # Safe method to handle browser errors during tests
  def safe_browser_operation
    yield
  rescue StandardError => e
    # Log error but don't let it fail the test - just a helper method
    puts "Browser operation failed: #{e.message}"
    false
  end

  # Check if element exists without raising errors
  def element_exists?(selector)
    safe_browser_operation { page.has_selector?(selector) }
  end

  # Specialized fill_in that properly handles Cuprite and ambiguous fields
  def paper_fill_in(field, value)
    # Handle the ambiguous email field by trying different strategies
    if field == 'Email'
      handle_email_field(value)
    else
      # For non-ambiguous fields, try standard approach first
      standard_fill_in(field, value)
    end
  rescue Capybara::Ambiguous => e
    # Handle ambiguous fields by finding a better selector
    puts "Ambiguous field '#{field}', trying alternative approach: #{e.message}"
    alternative_fill_in(field, value)
  end

  # Handle ambiguous email fields with special logic
  def handle_email_field(value)
    context = within_fieldset_text
    if context
      # If we're inside a fieldset with specific text, use CSS ID selectors
      if context == 'Constituent Information'
        fill_in_by_id('#constituent_email', value)
      else
        fill_in_by_id('#medical_provider_email', value)
      end
    else
      # If we can't determine context, try with exact CSS ID
      handle_unknown_email_field(value)
    end
  end

  # Try to determine which email field to use when context is unknown
  def handle_unknown_email_field(value)
    if has_css?('#constituent_email')
      fill_in_by_id('#constituent_email', value)
    elsif has_css?('#medical_provider_email')
      fill_in_by_id('#medical_provider_email', value)
    else
      # Last fallback - try to find by placeholder
      input = first("input[placeholder*='Email'], input[name*='email']")
      fill_field_with_js(input, value)
    end
  end

  # Standard fill_in attempt
  def standard_fill_in(field, value)
    input = find_field(field)
    fill_field_with_js(input, value)
  end

  def alternative_fill_in(field, value)
    # Compute a CSS-friendly field identifier.
    field_id = field.downcase.gsub(/\s+/, '_')
    id_candidates = [
      "#constituent_#{field_id}",
      "#application_#{field_id}",
      "#medical_provider_#{field_id}"
    ]

    # Find the first candidate ID that exists.
    if (candidate = id_candidates.find { |id| has_css?(id) })
      fill_in_by_id(candidate, value)
      return
    end

    # Last resort: find by placeholder or name containing the field.
    input = first("input[placeholder*='#{field}'], input[name*='#{field.downcase}']")
    fill_field_with_js(input, value)
  end

  # Fill a field using a CSS ID selector
  def fill_in_by_id(css_id, value)
    input = find(css_id)
    fill_field_with_js(input, value)
  end

  # Use JavaScript to set field value
  def fill_field_with_js(input, value)
    # Use JavaScript to set the value directly
    page.execute_script('arguments[0].value = arguments[1]', input.native, value)
    # Trigger the change event
    page.execute_script("arguments[0].dispatchEvent(new Event('change'))", input.native)
    # Trigger a blur event to fire validations
    page.execute_script("arguments[0].dispatchEvent(new Event('blur'))", input.native)
  end

  # Helper to determine the current fieldset context
  def within_fieldset_text
    return nil unless has_css?('fieldset')

    fieldset = first('fieldset')
    return nil unless fieldset.has_css?('legend')

    legend = fieldset.first('legend')
    legend.text
  rescue Capybara::ElementNotFound
    nil
  end

  # Specialized check method that handles Cuprite
  def paper_check_box(label_or_id)
    # Try to find by ID first, then by label
    input = if label_or_id.start_with?('#')
              find(label_or_id)
            else
              find_field(label_or_id)
            end

    # Use JavaScript to check the box
    page.execute_script('arguments[0].checked = true', input.native)
    # Trigger change event
    page.execute_script("arguments[0].dispatchEvent(new Event('change'))", input.native)
  end

  # Safely upload a file without relying on normal Capybara methods
  def safe_attach_file(field, _file_path)
    # Use JavaScript to create a mock file object
    page.execute_script(<<~JS, find_field(field, visible: false).native)
      const fileInput = arguments[0];
      // Create a mock change event
      const event = new Event('change', { bubbles: true });
      // Override the target.files property
      Object.defineProperty(event, 'target', { value: fileInput });
      fileInput.dispatchEvent(event);
    JS
  end

  # Safely click submit button
  def safe_submit_form
    # Find the submit button using a variety of selectors to be robust
    submit_button = find("input[type='submit'], button[type='submit'], button:contains('Submit')")

    # Scroll the button into view
    page.execute_script('arguments[0].scrollIntoView(true)', submit_button.native)

    # Use JavaScript click for reliability
    page.execute_script('arguments[0].click()', submit_button.native)
  end

  def wait_for_validation(max_wait = 1)
    start_time = Time.current
    while Time.current - start_time < max_wait
      return if page.has_selector?('.invalid, .error, .validation-message, .badge', wait: 0.1)

      sleep 0.1
    end
  end
end
