# frozen_string_literal: true

require 'application_system_test_case'

class BrowserTest < ApplicationSystemTestCase
  test 'Chrome for Testing is correctly configured' do
    # Visit the home page to check if Chrome for Testing works
    visit root_path

    # Take a screenshot to verify the browser is running
    take_screenshot

    # If we got this far, Chrome for Testing is working!
    assert true, 'Chrome for Testing is configured correctly'
  end
end
