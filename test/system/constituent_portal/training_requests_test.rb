# frozen_string_literal: true

require 'application_system_test_case'
require_relative '../../support/notification_delivery_stub'

module ConstituentPortal
  class TrainingRequestsSystemTest < ApplicationSystemTestCase
    setup do
      @constituent = users(:constituent_john)
      @application = applications(:one)

      # Set Current.user to avoid validation errors in callbacks
      Current.user = users(:admin_david)
      @application.update!(status: :approved)
      Current.reset

      # Set up training session policy
      Policy.find_or_create_by(key: 'max_training_sessions').update(value: 3)

      # Sign in as constituent
      sign_in(@constituent)
    end

    teardown do
      Current.reset
    end

    test 'constituent can view dashboard' do
      visit constituent_portal_dashboard_path
      assert_selector 'h1', text: 'My Dashboard'

      # Basic verification that the page loaded
      assert_selector '.bg-white'
      assert_selector '.bg-white', minimum: 3
    end
  end
end
