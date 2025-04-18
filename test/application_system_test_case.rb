# frozen_string_literal: true

require 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemTestAuthentication # Include authentication helper
  include SystemTestHelpers # Include helpers for working with Cuprite

  # Switch from headless_chrome to cuprite
  driven_by :cuprite
end
