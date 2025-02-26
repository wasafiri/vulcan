require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include VoucherTestHelper

  driven_by :headless_chrome

  def setup
    super
    @routes = Rails.application.routes
  end

  def sign_in(user)
    visit sign_in_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password123"
    click_button "Sign In"
    assert_text "Signed in successfully"
  end

  def teardown
    super
    # Clear any uploaded files
    FileUtils.rm_rf(ActiveStorage::Blob.service.root)
    # Clear any emails
    ActionMailer::Base.deliveries.clear
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
