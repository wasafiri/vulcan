# frozen_string_literal: true

require 'application_system_test_case'

class SampleSystemTest < ApplicationSystemTestCase
  test 'visiting home page' do
    visit '/'
    assert_selector 'body'
  end
end
